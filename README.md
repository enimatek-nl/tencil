# Tencil

Tencil is a mustache-compatible JSON based template engine for Nim.
It aims to be a very light and easy to use template engine which is:

  - compatible with mustache {{.}}, {{>.}} (aka partials), {{!.}} (aka comments), {{#.}} and {{/.}} 
  - uses JsonNode as model for the template
  - only uses system nim libraries and is very lightweight in code

### Installation
Use nimble to install the package
```sh
$ nimble install tencil
```

### Learn by example

A simple example can be found in the `examples/` folder:

```nim
import tencil, json

type
    Todo = ref object
        id: int
        checked: bool
        message: string

proc newTodo(id: int, checked: bool, message: string): Todo =
    Todo(id: id, checked: checked, message: message)

proc main() =
    let tencil = newTencil()
    
    const file_begin = staticRead("begin.mustache")
    tencil.add("begin", file_begin)

    const file_end = staticRead("end.mustache")
    tencil.add("end", file_end)

    const data = staticRead("index.mustache")
    tencil.add("index", data)

    let todos = @[
        newTodo(0, true, "do dishes"),
        newTodo(1, false, "reset computer"),
        newTodo(2, false, "go outside")
    ]

    echo tencil.render("index", %*{
        "show": false,
        "todos": todos
    })

main()
```

The `index.mustache` looks like:

```mustache
{{>begin}}

<h4>Todos</h4>
<table>
    <thead>
        <tr>
        <th>id</th>
        <th>checked</th>
        <th>message</th>
        </tr>
    </thead>
    <tbody>
    {{#todos}}
        <tr>
            <td>{{id}}</td>
            <td>{{checked}}</td>
            <td>{{message}}</td>
        </tr>
    {{/todos}}
    </tbody>
</table>

{{! comment about 'show' to demo hide a block }}
{{#show}}
    <div>
        <h1>dont show this!</h1>
    </div>
{{/show}}

{{>end}}
```

License
----

MIT


**Free Software, Hell Yeah!**
