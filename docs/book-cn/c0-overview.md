## How to write a programming language?

#### 目标
- first-class function, 函数即是数据, 可以赋给变量
- 不可变数据. 变量一旦定义不可修改值.
- module. 模块即为一组函数的集合. 模块之间以树形结构联系起来.
- 一切语句皆为表达式. 也就是说一切语句都是有返回值的.
- 支持extension API
- 线程安全
- IDE友好, 提供API给IDE
- 实现debugger
- 实现profiler
- JIT

#### 以下不是我们的目标
- 性能
- 面向对象
- 

#### 设计
我们不讨论哪些设计是最好的, 但是尽量详细讨论各种设计如何实现.
为了快速达到
