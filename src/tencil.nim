import json, tables
from strutils import find, startsWith, replace

type
    Tencil* = ref object
        partials: Table[string, Tpartial]

    Tindex = tuple[tag: string, first: int, last: int]

    Tpartial = ref object
        raw: string
        scope: string
        cache: string
        tags: seq[Tindex]

proc newTencil*(): Tencil =
    Tencil()

proc search(self: Tencil, d: string, s: int, q: string): Tindex =
    result.first = d.find(q, s)
    if result.first != -1:
        result.last = d.find("}}", result.first)
        if result.last != -1:
            result.last += 1
            result.tag = d.substr(result.first, result.last)

proc searchAll(self: Tencil, raw: string, q = "{{", f = ""): seq[Tindex] =
    var last = 0
    while true:
        let v = self.search(raw, last, q)
        if v.first == -1: break
        if f == "" or not v.tag.startsWith(f):
            result.add(v)
        last = v.last

proc find(self: Tpartial, q: string): int =
    for i, tag in self.tags:
        if tag.tag == q:
            return i
    return -1

proc add*(self: Tencil, name: string, raw: string) =
    self.partials[name] = Tpartial(raw: raw)

proc compile(self: Tencil, partial: Tpartial, child: JsonNode, first: int, last: int) =
    var i = first
    if i >= partial.tags.len: return
    while i <= last:
        # only add template between tags (begin + end are added in proc render)
        if i != 0: partial.cache &= partial.scope.substr(partial.tags[i - 1].last + 1, partial.tags[i].first - 1)
        # now match the new tag and choose the value to add
        if partial.tags[i].tag.startsWith("{{#"):
            let t = partial.scope.substr(partial.tags[i].first + 3, partial.tags[i].last - 2)                     # get the actual tagname
            let e = partial.find("{{/" & t & "}}") # get the index of the closing tag (needed for scoping or skip)
            i += 1 # failsafe
            if not child{t}.isNil:
                # check if the value is a boolean or int or json object to recurse
                if child{t}.kind == JBool or child{t}.kind == JInt:
                    # Int and Bool that is negative should skip the block
                    if child{t}.kind == JBool and not child{t}.to(bool): i = e + 1
                    if child{t}.kind == JInt and not child{t}.to(int) > 0: i = e + 1
                elif child{t}.kind == JArray:
                    if e != -1:
                        # recursive go through this block
                        for node in child{t}.to(seq[JsonNode]):
                            self.compile(partial, node, i, e)
                        i = e + 1
        elif partial.tags[i].tag.startsWith("{{/") or partial.tags[i].tag.startsWith("{{!"):
            # we can skip closing and comment tags
            i += 1
        else:
            # add the value
            let t = partial.scope.substr(partial.tags[i].first + 2, partial.tags[i].last - 2)
            if not child{t}.isNil:
                partial.cache &= (if child{t}.kind == JString: child{t}.to(string) else: $child{t})
            i += 1

proc render*(self: Tencil, name: string, model: JsonNode): string =
    if self.partials.contains(name):
        let partial = self.partials[name]

        # setup the scope (import all partials on place)
        if partial.scope == "":
            let partials = self.searchAll(partial.raw, q = "{{>")
            partial.scope = partial.raw
            for p in partials:
                let t = p.tag.substr(3, p.tag.len - 3);
                if self.partials.contains(t):
                    partial.scope = partial.scope.replace(p.tag, self.partials[t].raw)
            # build the tags lookuptable for the scope
            partial.tags = self.searchAll(partial.scope, f = "{{>")

        # start filling the tags from model
        partial.cache = partial.scope.substr(0, partial.tags[0].first - 1) # reset scope and add beginning
        self.compile(partial, model, 0, partial.tags.len - 1) # go through all tags
        partial.cache &= partial.scope.substr(partial.tags[^1].last + 1) # add last part of the content to scope

        return partial.cache
    return ""

