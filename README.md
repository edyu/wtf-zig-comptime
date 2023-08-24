# Zig Comptime -- WTF is Zig Comptime (and Inline)

The power and complexity of **Comptime** and **Inline** in Zig

---

Ed Yu ([@edyu](https://github.com/edyu) on Github and
[@edyu](https://twitter.com/edyu) on Twitter)
August.23.2023

---

![Zig Logo](https://ziglang.org/zig-logo-dark.svg)

## Introduction

[**Zig**](https://ziglang.org) is a modern systems programming language and although it claims to a be a **better C**, many people who initially didn't need systems programming were attracted to it due to the simplicity of its syntax compared to alternatives such as **C++** or **Rust**.

However, due to the power of the language, some of the syntaxes are not obvious for those first coming into the language. I was actually one such person.

Today we will explore a unique aspect of metaprogramming in **Zig** in its `comptime` and `inline` keywords. I've always known `comptime` is special in **Zig** but I never used it extensively until recently when I was implementing [erasure coding](https://github.com/beachglasslabs/eraser). Although the new implementation removed much of the `comptime` used in the project, I believe it's illuminating to explain my learning journey in `comptime` (and `inline`) while implementing the initial mostly `comptime` [version](https://github.com/beachglasslabs/eraser/tree/405a6809c387eb83de279b2f9f9fb15e5e37ee18) of that project because it allowed me certainly to gain a better grasp both in the power and the restriction of `comptime`.

## WTF is Comptime

If you start learning about **Zig**, you'll certainly encounter the `comptime` keywords, and you'll notice it's sprinkled in many places.

For example, in the signature for `ArrayList`, you'll notice it's written as `pub fn ArrayList(comptime T: type) type`. You know that when you create an `ArrayList`, you do need to pass in a type such as `var list = std.ArrayList(u8).init(allocator);`.

You'd most likely take a mental note that when you declare a type as a function parameter, you need to declare that type as *comptime*. And for many use cases, that's all you need to know about `comptime` and go your merry way.

[Loris Cro](https://kristoff.it) wrote ["What is Zig's Comptime?"](https://kristoff.it/blog/what-is-zig-comptime/) in 2019 and you are welcome to read through that first.

So, what exactly is `comptime`? If we look at it literally, the *comp* part of `comptime` stands for **compile** so `comptime` really means **compile time**. The keyword `comptime` is a label that you can apply to a variable to say that the variable can only be changed during `comptime` so that after the program is compiled and during *runtime* (when running the program), that variable is essentially `const`.

That was a mouthful so why would you make a variable `comptime`? It would allow you to create [macros](https://en.wikipedia.org/wiki/Macro_(computer_science)) because macros are **compile time**. And note that one of the reasons that [Andrew](https://github.com/andrewrk) created **Zig** initially is to remove macros from the **C** so `comptime` is the answer to the **C** macro use case. I know the previous sentences are somewhat contradictory so what I mean really is that `comptime` was invented to allow the use cases of macros by using `comptime` instead.

Now the question is what is a macro? One way to think about it is that macros are substitutions that happen during **compile time** as part of a *preprocessor*. A *preprocessor* is a step before the regular compilation (although it happens normally as part of compilation).

In **C**, for example, you often use macros to define a constant such as this:

```c
// a constant
#define MY_CONST 5
```

And after you define the constant, you can then use such constant anywhere in your code. The preprocessor would *substitute* everywhere the macro is used with the value that was defined (in this case 5).

```c
printf("The constant is %d", MY_CONST);
```

In **Zig**, you can just say:

```zig
const MY_CONST = 5;

std.debug.print("The constant is {d}", .{MY_CONST});
```

This is not very useful but often people define more complex macros such as the following:

```C
// double a number
// you need the () around x because you might call square(4 + 2)
#define square(x) ((x) * (x))
// find the minimum of 2 numbers
#define min(a, b) (((a) < (b)) ? (a) : (b))
```

## WTF is Inline

So why would those **C** macros be useful? Why can't we just define these as regular functions?

Often people use macros instead of functions because they want to optimize the code by not incurring the overhead of calling a function.

In this case, **Zig** introduced an `inline` keyword so that you can do the following:

```zig
// note that this will overflow
// but I left it in this form intentionally
// to mimic the simplicity of the C macro
pub inline fn square(x: i32) i32 {
    return x * x;
}

pub inline fn min(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

test "square" {
    try std.testing.expectEqual(9, square(3));
    try std.testing.expectEqual(25, square(3 + 2));
}

test "min" {
    try std.testing.expectEqual(min(2, 3), 2);
    try std.testing.expectEqual(min(3, 3), 3);
    try std.testing.expectEqual(min(-1, -3), -3);
}
```

As you can see, by using `inline`, **Zig** would effectively *inline* (substitute) the function calls in code without incurring the overhead of a function call.

## WTF is Comptime_Int

As you can see from our test code, that we are using constants or just numbers, so we can actually rewrite the functions by introducing a new type as `comptime_int`. By denoting the type as `comptime_int`, the compiler would automatically figure out what's the best type to use because the inputs to the functions are known at **compile time** or `comptime`. Note that you have to add the `comptime` keyword in front of the variable names in the argument. You do not need to denote the return type as `comptime` however.

```zig
pub fn squareComptime(comptime x: comptime_int) comptime_int {
    return x * x;
}

pub inline fn minComptime(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return if (a < b) a else b;
}

test "squareComptime" {
    try std.testing.expectEqual(9, squareComptime(3));
    try std.testing.expectEqual(25, squareComptime(3 + 2));
}

test "minComptime" {
    try std.testing.expectEqual(minComptime(0, 0), 0);
    try std.testing.expectEqual(minComptime(30000000, 30000000000), 30000000);
    try std.testing.expectEqual(minComptime(-10, -3), -10);
}
```

Note that I marked `squareComptime` as a regular function but denoted `minComptime` as an `inline` function. In other words, `inline` and `comptime` are not exclusive to each other. You don't have to have both even if both are used at **compile time**.

## Why Not Comptime Everything


When I first started using `comptime`, I realized two problems:
1. `comptime` in some way *pollutes* the code it touches. What I mean is that once you `comptime` something, everything it uses would also need to be `comptime`. I'll show a more complex example later.
2. The other problem is that as soon as you need to start using a *runtime* value such as passing in a commmand-line argument, you'll encounter errors while compiling your code.

Let me illustrate the problem 2 here.
Say I want to pass in numbers during *runtime* by passing in the number on the command-line (same problem from a file, or from user input), you will have a hard time calling the `squareComptime` and `minComptime` versions.

My friend [InKryption] put it succinctly in a quote: "comptime exists in a sort of pure realm where I/O doesn't exist."

If you try to pass in a command-line argument to the function:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var x = try std.fmt.parseInt(i32, args[1], 10);
    var y = squareComptime(x);
    std.debug.print("square = {d}\n", .{y});
}
```

And then run the program:

```bash
> zig run main.zig -- 1337
```

You'll encounter the following error:

```bash
error: unable to resolve comptime value
var y = squareComptime(x);
```

In other words, once you make your function `comptime` by making a parameter `comptime`, you cannot pass non-`comptime` parameters such as a command-line argument.

On the other hand, if all your parameters of a function are `comptime`, you can make a variable that takes in the return value of the function `comptime`.

```zig
test "comptime" {
    comptime var y = squareComptime(1337);
    // you can now pass y to anything that requires comptime
    comptime var z = minComptime(y, 7331);
    try std.testing.expectEqual(z, 1337);
}
```

The only way to *fix* problem 2 is to make your functions non-`comptime`.

```zig
// while we are at it, might as well fix the overflow problem
pub inline fn squareNoOverflow(x: i32) u64 {
    return @intCast(std.math.mulWide(i32, x, x));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var x = try std.fmt.parseInt(i32, args[1], 10);
    var y = squareNoOverflow(x);
    std.debug.print("square = {d}\n", .{y});
}
```

Now run it with a command-line argument:

```bash
> zig run main.zig -- 1337
square = 1787569
```

## Unrolling Loops with Inline

I've already mentioned one common use of `inline` by prefixing the function declaration with the keyword `inline` to *inline* the function for efficiency reasons. The even more common use than *inlining* a function with `inline` is to *unroll* a loop by prefixing a `for` loop with `inline`.

For example, say I need to calculate the factorial of a number. We know that that factorial of a number `n` is written as `n!` and it means `n * (n - 1) * (n - 2)...1`. In other words, `2!` is `2 * 1 = 2`, `3!` is `3 * 2 * 1 = 6`, `4!` is `4 * 3 * 2 * 1 = 24`, and so on.
For the special cases of `1!` and `0!`, they are both `1`.

Although factorial are often written as a recursive function, it's also fairly easy and efficient to just use a for loop.

Let's write a `comptime` version:

```zig
pub fn factorial(comptime n: u8) comptime_int {
    var r = 1; // no need to write it as comptime var r = 1
    for (1..(n + 1)) |i| {
        r *= i;
    }
    return r;
}
```

When you prefix a `for` loop with the `inline`, you are effectively [*unrolling*](https://en.wikipedia.org/wiki/Loop_unrolling) the loop so that each iteration of the loop is executed sequentially without branching. This is usually done also for efficiency reasons.

When you `inline` the loop, the loop can still do *runtime* stuff but the loop branching and the iteration variables are now `comptime`.

```zig
pub fn factorial(comptime n: u8) comptime_int {
    var r = 1; // no need to write it as comptime var r = 1
    inline for (1..(n + 1)) |i| {
        r *= i;
    }
    return r;
}
```

## WTF is Type Function

The real power of `comptime` lies in something called a *type function*. Earlier when I showed the signature of `ArrayList`, it's actually a *type function*. A *type function* is simply a function that returns a type.

Let's see the `ArrayList` *type function* again:

```zig
pub fn ArrayList(comptime T: type) type {
    return ArrayListAligned(T, null);
}
```

As you can see because the *type function* returns a type, the function name is usually capitalized by convention as if it's a type.
Effectively you can use *type function* anywhere a type is usually required such as type annotation, function arguments, and even return types. However, take note that *type function* name by itself is not a type, because it's a function, you need to actually supply it with the parameters it needs. For example, `ArrayList` is not a type, but `ArrayList(u8)` is a type because the `ArrayList` *type function* requires a type as its parameter specified as `comptime T: type`.

For example, say I need to implement a function that allows me to calculate the combinatorics of `m choose n`. From your high-school maths, you know that `(m choose n)` is equal to `m! / (n! * (m-n)!)`. In other words, if you have 3 items and you want to get all the combinations of 2 items from those 3 times, you can use such function to calculate how many unique combinations you'd get. So for `(3 choose 2)`, you have `3! / (2! * 1!) = (6 / 2) = 3`.

You can use the following function to do the maths:

```zig
pub fn numChosen(comptime m: u8, comptime n: u8) comptime_int {
    return factorial(m) / (factorial(n) * factorial(m - n));
}
```

If you want to get all the actual permutations of such combinatorics, you need to have some way of grouping the permutations together, and for `(3 choose 2)` or the 6 permutations, you need to have a group of 6 items where each item is a combination of 2 indices. For example, say you have `(0, 1, 2)` as in the input, you want to get back an array of `[6][2]u8`, which is an array of 6 items where each of the item is an array of 2 `u8`s.

The reason why we use array instead of an `ArrayList` is to not only be able to find the permutations in `comptime` but also we don't have to deal with allocators. 

In order to make this work, we need to have a *type function* that would simplify the return type of our function.

```zig
pub fn ChosenType(comptime m: u8, comptime n: u8) type {
    comptime var t = numChosen(m, n);
    return [t][n]u8;
}
```

As you can see, this function calls the previously defined `numChosen` to calculate the number of items in the return array type.
The return type of the *type function* is a type.

Now for the final implementation of the `choose` function that returns all the permutations.

```zig
pub fn choose(comptime l: []const u8, comptime k: u8) ChosenType(l.len, k) {
    std.debug.assert(l.len >= k);
    std.debug.assert(k > 0);

    var ret: ChosenType(l.len, k) = std.mem.zeroes(ChosenType(l.len, k));

    if (k == 1) {
        inline for (0..l.len) |i| {
            ret[i] = [k]u8{l[i]};
        }
        return ret;
    }
    comptime var c = choose(l[1..], k - 1);
    comptime var i = 0;
    inline for (0..(l.len - 1)) |m| {
        inline for (0..c.len) |n| {
            if (l[m] < c[n][0]) {
                ret[i][0] = l[m];
                inline for (0..c[n].len) |j| {
                    ret[i][j + 1] = c[n][j];
                }
                i += 1;
            }
        }
    }
    return ret;
}
```

## Dependency Order of Comptime Arguments and Return Type

You function doesn't have to make all the arguments `comptime` unless you need to use the function in `comptime` such as a *type function*.

There is however an order of `comptime` variable dependency. What I mean is that if you have 2 `comptime` parameters, then the latter parameter can depend on the earlier `comptime` parameter. This is true regardless of the number of parameters in the function, and the return type of the function can depend on the values of the `comptime` variables defined in the parameters of the function.

In the `choose` function, the return type `ChosenType(m, n)` depends on both of the 2 parameters in function arguments. In this particular function, it actually depends on the length of the first `comptime` slice and the number passed in as the 2nd argument.

A more complex example is in used my code where although I didn't need to pass in the `comptime z` parameter, I had to because I need that parameter to determine both what matrix to allow multiplying to and the result matrix. In other words, when you multiple an `m x n` (self) matrix with an `n x z` (other) matrix, you know the type must be an `m x z` (return type) matrix. However, because I cannot specify the parameter of the (other) matrix without knowing both values of `n` and `z` from some other parameter except when it's already passed in in the argument, I have to take in an extra `z` parameter.

```zig
pub fn multiply(self: *Self, comptime z: comptime_int, other: BinaryFieldMatrix(n, z, b)) !BinaryFieldMatrix(m, z, b)
```

In this particular function declaration, `BinaryFieldMatrix` is a *type function* as well.

This is actually one of the manifestation of the problem 1 I mentioned earlier in the section **WTF is Comptime_Int**.

I originally made `Matrix` a *type function* that takes in `comptime` values, and that made both `BinaryFiniteField` and `BinaryFieldMatrix` *type functions*, which in turn made my `ErasureCoder` also a *type function*, and everything depended on `comptime` values to initialize which worked great when I was testing the code.

However, when I started running the code by specifying command-line arguments I realized that I cannot pass in any command-line arguments to construct the `ErasureCoder` because command-line arguments cannot be forced into `comptime` even if I prepend the variable name with `comptime`.

Now I'm going to end with the platitude of "great power comes with great responsibility". Use your `comptime` wisely, my friend!

## Bonus

The keyword `comptime` in fact can be put in front of any expression such as a loop, or a block, or even a function.

When you do so, you are effectively making that expression `comptime`.

For example, when you call the factorial function, you can prepend `comptime` to the function call and then the function would be run at comptime and it would not take any run-time resource to calculate the factorial. So it doesn't matter whether it's `5!` or `10!`, at *run time*, it's really just a constant that was calculated at **compile time**.

```zig
pub fn main() !void {
    const z = comptime factorial(50);
    std.debug.print("10! = {d}\n", .{z});
}
```

```bash
> zig run main.zig
10! = 3628800
```

## The End

You can read [Loris Cro](https://kristoff.it)'s blog ["What is Zig's Comptime?"](https://kristoff.it/blog/what-is-zig-comptime/).

You can find the code [here](https://github.com/edyu/wtf-zig-comptime) and the older code that mostly uses `comptime` is [here](https://github.com/beachglasslabs/eraser/tree/405a6809c387eb83de279b2f9f9fb15e5e37ee18).


Special thanks to [InKryption](https://github.com/inkryption) for helping out on **comptime** questions!

The erasure coding project I mentioned earlier is [here](https://github.com/beachglasslabs/eraser).

## ![Zig Logo](https://ziglang.org/zero.svg)
