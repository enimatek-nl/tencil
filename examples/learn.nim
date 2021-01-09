import ../src/tencil, json

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

    echo tencil.render("index", %*{"show": false, "todos": todos})

main()
