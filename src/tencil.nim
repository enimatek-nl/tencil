import re, json, tables

type
    Tencil* = ref object
        partials: Table[string, Tpartial]

    Tpartial = ref object
        raw: string
        scope: string
        cache: string
        tag_names: seq[string]
        tag_pos: seq[tuple[first: int, last: int]]

proc newTencil*(): Tencil =
    Tencil()

proc add*(self: Tencil, name: string, raw: string) =
    self.partials[name] = Tpartial(raw: raw)

proc compile(self: Tencil, partial: Tpartial, child: JsonNode, first: int, last: int) =
    var i = first
    if i >= partial.tag_names.len: return
    while i <= last:
        # only add template between tags (begin + end are added in proc render)
        if i != 0: partial.cache &= partial.scope.substr(partial.tag_pos[i - 1].last + 1, partial.tag_pos[i].first - 1)
        # now match the new tag and choose the value to add
        if partial.tag_names[i].startsWith(re"{{#"):
            let t = partial.scope.substr(partial.tag_pos[i].first + 3, partial.tag_pos[i].last - 2) # get the actual tagname
            let e = partial.tag_names.find("{{/" & t & "}}") # get the index of the closing tag (needed for scoping or skip)
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
                            self.compile(partial, node, i + 1, e)
                        i = e + 1
        elif partial.tag_names[i].startsWith(re"{{/") or partial.tag_names[i].startsWith(re"{{!"):
            # we can skip closing and comment tags
            i += 1
        else:
            # add the value
            let t = partial.scope.substr(partial.tag_pos[i].first + 2, partial.tag_pos[i].last - 2)
            if not child{t}.isNil:
                partial.cache &= (if child{t}.kind == JString : child{t}.to(string) else: $child{t})
            i += 1

proc render*(self: Tencil, name: string, model: JsonNode): string =
    if self.partials.contains(name):
        let  partial = self.partials[name]
        let partials = partial.raw.findAll(re"{{>[\/\_a-zA-Z0-9\s]*}}")

        # setup the scope (import all partials on place)
        if partial.scope == "":
            partial.scope = partial.raw
            for p in partials:
                let t = p.substr(3, p.len - 3);
                if self.partials.contains(t):
                    partial.scope = partial.scope.replace(re(p), self.partials[t].raw)

        # build the tag position lookup arrays:
        partial.tag_names = partial.scope.findAll(re"{{[\#\!\/\_a-zA-Z0-9\s]*}}")
        partial.tag_pos = @[]
        var p = 0
        for i, tag in partial.tag_names:
            let f = partial.scope.findBounds(re("(" & tag & ")"), start = p)
            partial.tag_pos.add(f)
            p = f.last + 1

        # start filling the tags from model
        partial.cache = partial.scope.substr(0, partial.tag_pos[0].first - 1) # reset scope and add beginning
        self.compile(partial, model, 0, partial.tag_names.len - 1) # go through all tags
        partial.cache &= partial.scope.substr(partial.tag_pos[^1].last + 1) # add last part of the content to scope
        
        return partial.cache
    return ""

