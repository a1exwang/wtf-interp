### An interpreted language inspired by Ruby, Elixir, CoffeeScript, Python, etc

##### Learn from Examples

- Basic Data Types

```
  # Integers
  a = 1;
  
  # Strings
  b = "abc";
  
  # Lists
  lst = [1, 2, 5, "hello world"];
  each(lst, -> (item) { puts(item); });
  puts(lst[3]);

  # 2D list
  lst1 = [[1, 3, 5],
          [2, 4, 6],
          [3, 5, 7]];
  puts(to_s(lst1[0][0]));

  # Booleans and Nil
  puts([True, False, Nil]);
  
  # Hash Map
  map = {a: 2 + 3};
  puts(map["a"]);
  
  # Functions
  puts(Type::is_a(1, Type::Int));
  puts(Type::is_a(1, Type::Float));
  puts(Type::is_a(Type::is_a, Type::Function));
```

- Operators

```
  puts(-1);
  puts(1 + 2);
  puts(1 - 2);
  puts(1 * 2);
  puts((3 + 4) * 5);
  puts("abc" == "abc");
  puts("abc" != "abcd");
  puts("abc" != 1);
  puts(Nil == Nil);
  puts(1 > 2);
  puts(1 >= 1);
```

- Basic Statements
```
  puts(
    if (True) {
      "true";
    } else {
      "false";
    }
  );
```

- Functions as First Citizens

```
  fn = -> (x, y) {
    x + y;
  }
  
  fn1 = -> (fn) {
    fn(3, 5);
  };
  
  fn1(fn);
  
```

- Modules

```
  C = module {
    B = module {
      A = 1;
    };
  };
  puts(C::B::A);
  
  include(C::B);
  puts(A);
```

- require() v.s. import()
```
  # a.wtf
  A = 1
  
  # b.wtf
  B = 2
  
  # "require" is like Ruby's require
  # It defines all vars of the required file in current bindings
  
  # require.wtf
  a = require("./a");
  puts(A); # => 1
  puts(a); # => 1
  
  # "import" is like Python's import
  # It does not affect current bindings,
  #   but returns a module object containing 
  #   all vars defined in the imported file
  
  # import.wtf
  b = import("./b");
  puts(b);      # => <module ./b.wtf>
  puts(b::B);   # => 1
```

- Pattern Matching

```
  let {a: a} = {a: 1};
  let {b: [b, c]} = {b: [2, 3]};
  puts(a);
  puts(b);
  puts(c);

  let d = 4;
  let {} = {};
  let [] = [];
  let [{e: e}] = [{e: 5}];
  puts(d);
  puts(e);

  let [f, g, _] = [1, 2, 3];
  let [h, i, *j] = [1, 2, 3, 4, 5];
  puts(j);
```

- Exceptions
```
  secure {
    let [a, b, c, d] = [1, 2, 3];
  } rescue {type: type, message: message} {
    puts("rescue");
    puts(to_s(type));
  };
```

- Misc
```
  # "eval" is not so "evil"
  puts(eval("-> { puts(2+3); }")());
  
  # Command Line Arguements
  puts(ARGV);
```

### TODOs
- syntax
  - regex
  - "is" operator, binary comparison operator
  - Don't need "main" function
  - NO operator overriding

- stdlib
  - math
  - io
  
### Language Design 

1. Main Goals
    1. Make the programmers happy.
    1. Functional.
    1. What-you-see-is-what-you-get syntax.
    1. Simple basic syntax plus syntax sugars.
    1. Code fast, cod short.
    1. Do not refactor, rewrite it.
    1. Ruby inter-ops.
    1. Threads are shit.
    
### Design Details

- wtf.rb
    - Interpret executable
    
- lexer.rb
    - Lexer
    
- parse.y
    - yacc-like parser
    
- eval.rb
    - Implement "eval"-like functions in Ruby
    - e.g. eval(str), require(file), import(file)
 
- vm.rb
    - Interpreter virtual machine
    - The virtual machine executes AST nodes
    
- api.rb
    - Ruby inter-ops
    
- ast/nodes.rb
    - AST Node definitions 

- stdlib/kernel.rb
    - Basic wtf data types and kernel functions in Ruby
    
- How the interpreter runs your code
    1. Parser runs, and drives the lexer. Generate an AST.
        - Each node knows its children
    1. AST traversal 1
        - Each node knows its parent, and the interpreter knows the entry point
    1. Evaluate the AST node of the "main" function
    
- Ruby and wtf objects
    1. Each wtf object type is a WtfType objects
    1. wtf exception is Ruby Wtf::Lang::Exception::WtfError

- Bindings
    1. Bindings change only at function or module definitions or ensure..rescue block
