# Change log for wtf-interpreter

## [0.4.0] 2017-05-30
- Syntax
  - Pattern matching case-when statments
- Bug fix
  - Fix constant pattern matching bug

## [0.3.3] 2017-05-27
- "if" statement without "else"

## [0.3.2] 2017-05-27
- Syntax
  - Function definitions now supports
    list pattern matching

## [0.3.1] 2017-05-26
- Stdlib
  - require/import supports relative path
  - Add readline support to stdlib
- Syntax
  - Add comparison operators
- Bug fix
  - Fix "if" expression bound to global bindings bug
  - Test scripts also check stderr
  - Test scripts cleaner format

## [0.3.0] 2017-05-26
- Interpreter
  - We don't need a 'main' function
  - Implement Ruby-like require and Python-like import

## [0.2.1] 2017-05-26
- Stdlib
  - exit(exit\_code)
  - include(module)
  - local_var_names()
- Bug fix
  - Fix ModuleType object 'to_s' bug

## [0.2.0] 2017-05-21
- Interpreter
  - Expose meta objects of data types in stdlib
  - Float data type
- Stdlib
  - String
- Bug fix
  - exceptions var redefinition bug
