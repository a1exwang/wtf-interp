# Change log for wtf-interpreter

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
