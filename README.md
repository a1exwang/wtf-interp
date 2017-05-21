### An interpreted language inspired by Ruby, Elixir, CoffeeScript, Python, etc

##### Learn from Examples

- Basic Data Types

```
  # Integers
  a = 1;
  
  # Strings
  b = "abc";
  
  # list literal
  lst = [1, 2, 5, "hello world"];
  each(lst, -> (item) { puts(item); });
  puts(lst[3]);

  # 2D list
  lst1 = [[1, 3, 5],
          [2, 4, 6],
          [3, 5, 7]];
  puts(to_s(lst1[0][0]));

  # boolean and nil
  puts([True, False, Nil]);
  
  # Hash Map
  map = {a: 2 + 3};
  puts(map["a"]);
```

- Operators

```
  puts(1 + 2);
  puts(1 - 2);
  puts(1 * 2);
  puts((3 + 4) * 5);
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
- Data Types
  - float

- syntax
  - regex
  - "is" operator

- stdlib
  - math
  - io
  - string
