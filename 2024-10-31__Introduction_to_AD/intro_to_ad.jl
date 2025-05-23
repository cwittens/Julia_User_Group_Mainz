### A Pluto.jl notebook ###
# v0.20.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ fcd42a91-52bb-472a-bdf5-1dc6dc88746a
begin
	using PlutoUI
	using PlutoUI: Slider # since Makie exports Slider, too
end

# ╔═╡ fca087a8-babf-4115-ace8-ac9f4d357684
begin
	using CairoMakie
	set_theme!(theme_latexfonts();
			   fontsize = 16,
			   Lines = (linewidth = 2,),
			   markersize = 16)
end

# ╔═╡ 01e58263-94b8-4685-a7d7-48d2eb0d5ab3
using LinearAlgebra

# ╔═╡ 65b90601-fa37-448a-a9d3-6fcee665d791
using LaTeXStrings

# ╔═╡ 6fcc36b0-7845-4c19-83f5-35c0ffbd9c66
using DoubleFloats

# ╔═╡ 4550d944-23dd-45af-a4c2-356b8a0be13a
using BenchmarkTools

# ╔═╡ 5a1bf2d0-d67f-4157-8095-d8a458431a6a
using StaticArrays

# ╔═╡ 91df7c2f-c6d6-4c45-b965-0ff13c17434c
using Enzyme

# ╔═╡ 3df9311e-92a0-11ef-3b43-d9393641d811
md"""
# Introduction to automatic/algorithmic differentiation (AD)

This presentation provides and introduction to automatic/algorithmic differentiation (AD),
one of the cornerstones of modern machine learning and scientific computing. There is
of course a wide variety of AD techniques and much more to learn. Here, we will
concentrate on a very simple version and its implementation in Julia - forward-mode AD.
"""

# ╔═╡ b3ae7754-8839-479b-8134-bca0a66aa294
md"""
#### Initializing packages

_When running this notebook for the first time, this could take up several minutes. Hang in there!_
"""

# ╔═╡ 23c7e21c-1f58-4a43-9a18-f4d0360e0abc
md"""
## Finite differences

There are several ways to compute a function and its derivative on a computer.
If you use a computer algebra system (CAS), you can compute derivatives analytically,
e.g., using [Wolfram Alpha](https://www.wolframalpha.com).

Another option you should have seen in the introduction to numerical analysis are finite differences. Since the derivative is defined as

$$f'(x) = \lim_{h \to 0} \frac{f(x + h) - f(x)}{h},$$

it makes sense to use the forward difference

$$\frac{f(x + h) - f(x)}{h} \approx f'(x)$$

and approximate the limit by taking a small $h > 0$. However, this leads to round-off
error since we typically represent real numbers via *floating point numbers with fixed precision*.
"""

# ╔═╡ 028d57c4-0ebc-4359-888d-65ecd080fe0f
eps(1.0)

# ╔═╡ 702c0ce9-aa9c-4240-a8fb-b492a431b180
eps(1.0f0)

# ╔═╡ 88602567-bbc3-4244-91b7-78f11087fcce
eps(1.234e5)

# ╔═╡ 7d9ad4f0-33ea-4afb-8834-3d3a6645a4ee
md"""
Thus, there will be two regimes:
- if $h$ is too big, the error of the limit approximation dominates
- if $h$ is too small, the floating point error dominates

We illustrate this for different functions $f$ at $x = 1$. We use different types of floating point numbers and compute the error of the
finite difference approximation.
"""

# ╔═╡ 22832ba3-257f-4daa-b8eb-5ea6094b50c7
@bind FloatType Select([Float32, Float64, Double64]; default = Float64)

# ╔═╡ ab64c9c0-5177-45c8-8422-8f09f84af990
md"""
Next, we use the central difference

$$\frac{f(x + h) - f(x - h)}{2 h} \approx f'(x).$$
"""

# ╔═╡ f8ee1a92-208f-4558-a797-aca82c272804
md"""
## Forward-mode AD for scalars

There is a well-know proverb

> Differentiation is mechanics, integration is art

Luckily, we are just interested in differentiation for now. Thus, all we need to do
is to implement the basic rules of calculus like the product rule and the chain rule.
Before doing that, let's consider an example.
"""

# ╔═╡ a1666545-2256-4015-bee8-2b6a80693ea3
md"""We can compute the derivative by hand using the chain rule."""

# ╔═╡ 33b67c04-8e28-4361-a572-6379f3a69ac0
md"We can think of the function as a kind of *computational graph* obtained by dividing it into steps."

# ╔═╡ 190fc532-f613-4226-9553-ecae2dc08614
md"To compute the derivative, we have to apply the chain rule multiple times."

# ╔═╡ 1811b4ff-f45a-4144-8f67-abddc79c1f1c
md"""
We would like to automate this! To do so, we introduce so-called [dual numbers](https://en.wikipedia.org/wiki/Dual_number). They carry both a `value` and derivative (called `deriv`, the ε part above). Formally, a dual number can be written as

$$x + \varepsilon y, \qquad x, y \in \mathbb{R},$$

quite similar to a complex number

$$z = x + \mathrm{i} y, \qquad x, y \in \mathbb{R}.$$

However, the new basis element $\varepsilon$ satisfies

$$\varepsilon^2 = 0$$

instead of $\mathrm{i}^2 = -1$. Thus, the dual number have the algebraic structure of an *algebra* instead of a field like the complex numbers $\mathbb{C}$.

In our applications, the $\varepsilon$ part contains the derivative. Indeed, the rule $\varepsilon^2 = 0$ yields

$$(a + \varepsilon b) (c + \varepsilon d) = a c + \varepsilon (a d + b c),$$

which is just the product rule of calculus. You can code this as follows.
"""

# ╔═╡ a8e22d08-c2c8-4ee4-87fe-7b665edc4a3e
begin
	struct MyDual{T <: Real} <: Number
		value::T
		deriv::T
	end
	MyDual(x::Real, y::Real) = MyDual(promote(x, y)...)
end

# ╔═╡ 9367a32a-160f-418b-9938-8e766a77e475
md"Now, we can create such dual numbers."

# ╔═╡ d329aecc-4696-4740-9a86-d5da14cce69b
MyDual(5, 2.0)

# ╔═╡ 9881c9b3-c1df-4e69-827f-a06347240dc5
md"Next, we need to implement the required interface methods for numbers."

# ╔═╡ 597ac91c-ac82-4281-903e-57d82cd2c79b
Base.:+(x::MyDual, y::MyDual) = MyDual(x.value + y.value, x.deriv + y.deriv)

# ╔═╡ f48aeca4-2833-4571-82fa-dfddfc3f583b
Base.:-(x::MyDual, y::MyDual) = MyDual(x.value - y.value, x.deriv - y.deriv)

# ╔═╡ 151d76cf-a1ce-4b64-9661-b34ed516dd30
nextfloat(1.0) - 1.0

# ╔═╡ bbf4cecf-64c8-47c6-9f27-dbebbc59843a
(nextfloat(1.234e5) - 1.234e5)

# ╔═╡ 1489d2c7-4bd3-49b3-99e2-74ce1e2211ce
MyDual(1, 2) - MyDual(2.0, 3)

# ╔═╡ dab7c717-8980-4f52-b8af-b0d09577771f
md"We also need to tell Julia how to convert and promote our dual numbers."

# ╔═╡ 0dcab12e-8fbd-4b26-902f-00416f29a816
Base.convert(::Type{MyDual{T}}, x::Real) where {T <: Real} = MyDual(x, zero(T))

# ╔═╡ 4735f5ae-e497-4949-95d9-f90952a47435
Base.promote_rule(::Type{MyDual{T}}, ::Type{<:Real}) where {T <: Real} = MyDual{T}

# ╔═╡ 1a5f7311-ec24-4f3a-9d35-d8a636736ed1
md"Next, we need to implement the well-know derivatives of special functions."

# ╔═╡ d89ea840-631c-44e3-8839-9a055a961877
md"Finally, we can differentiate the function `f` we started with!"

# ╔═╡ 482a3cbc-b4cf-4cbd-aa35-7913d03840fb
md"This works since the compiler basically performs the transformation `f` $\to$ `f_graph_derivative` for us. We can see this by looking at one stage of the Julia compilation process as follows."

# ╔═╡ 4a47abae-0952-4da5-8260-ea35f22697a8
md"Since the compiler can see all the different steps, it can generate very efficient code."

# ╔═╡ cdd33aab-4c45-447c-a5a3-79610bb5621a
md"Now, we have a versatile tool to compute derivatives of functions depending on a single variable."

# ╔═╡ c31eb587-90e3-480a-921d-ebcddd749118
derivative(f, x::Real) = f(MyDual(x, one(x))).deriv

# ╔═╡ 5647fd0e-ce4c-4c54-b6b8-5bdcc4a74cd6
md"We can also get the derivative as a function itself."

# ╔═╡ 07b170ea-1fe4-43ac-b78a-c34e59a55526
derivative(f) = x -> derivative(f, x)

# ╔═╡ c98748bd-545f-49b6-bb6a-e06dd0719d73
md"""## Handling multiple variables

If we're dealing with multiple variables, we need to keep track of several 
partial derivatives at the same time. We can just reuse our scalar code for this.
"""

# ╔═╡ e6809491-e021-4696-bf44-49a9a1936ac4
function gradient_scalar(g, x, y)
	g_x = g(MyDual(x, 1), y).deriv
	g_y = g(x, MyDual(y, 1)).deriv
	return (g_x, g_y)
end

# ╔═╡ 75cc7eca-1f89-440b-bfd0-5b7624323c65
md"""
However, we need to compute our function twice to get two derivatives this way.
This is totally fine in this case but can be some overhead for larger applications.
To improve the performance, we can keep track of multiple derivatives at the
same time (sometimes referred to as *batching*). 
Thus, instead of having just a single scalar derivative value
in each `MyDual`, we have a vector of partial derivatives. If we're just dealing
with a fixed and small number of partial derivatives, it's more efficient to use
[StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl) for this."""

# ╔═╡ dfd400fa-dafc-4604-8064-ac0c88967965
begin
	struct MyMultiDual{N, T <: Real} <: Number
		value::T
		deriv::SVector{N, T}
	end
end

# ╔═╡ 1a764d54-fbf2-431b-8095-82c2d1e3eb8a
function Base.:+(x::MyMultiDual, y::MyMultiDual)
	MyMultiDual(x.value + y.value, x.deriv + y.deriv)
end

# ╔═╡ 6b8edf00-d973-4228-9524-86670e4a989a
MyDual(1, 2) + MyDual(2.0, 3)

# ╔═╡ 3c2c092d-2d52-4379-99f0-6ccc2d237668
function Base.:*(x::MyDual, y::MyDual)
	MyDual(x.value * y.value, x.value * y.deriv + x.deriv * y.value)
end

# ╔═╡ 590f30b1-9c90-4b03-83da-bea3ea92dd60
MyDual(1, 2) + 3.0

# ╔═╡ 9b318e2a-8f7f-4350-86b6-0713e1603c42
function Base.:*(x::MyMultiDual, y::MyMultiDual)
	MyMultiDual(x.value * y.value, x.value * y.deriv + x.deriv * y.value)
end

# ╔═╡ ccf335ff-e40d-4144-8579-81c2c7c1046b
MyDual(1, 2) * MyDual(2.0, 3)

# ╔═╡ 4afbb4a3-3630-4e80-90b9-f7d1a946dc43
function Base.:/(x::MyDual, y::MyDual)
	MyDual(x.value / y.value, (x.deriv * y.value - x.value * y.deriv) / y.value^2)
end

# ╔═╡ 92a7e494-86b5-4d1f-ad6b-622b5f184bfe
MyDual(1, 2) / MyDual(2.0, 3)

# ╔═╡ 28ae9185-edd2-4df4-a336-2c7face37228
Base.log(x::MyDual) = MyDual(log(x.value), x.deriv / x.value)

# ╔═╡ b6c470da-2708-4fe7-a95c-eeab90ff9944
log(MyDual(1.0, 1))

# ╔═╡ 72922b27-6172-44ca-93bc-e8380b92baca
function Base.sin(x::MyDual)
	si, co = sincos(x.value)
	return MyDual(si, co * x.deriv)
end

# ╔═╡ 9ce7e5e5-50db-44bb-9642-e6a25fa502f6
sin(MyDual(π, 1))

# ╔═╡ e79abdd7-cc18-4b7b-bc83-78e0e7cc00b2
function Base.cos(x::MyDual)
	si, co = sincos(x.value)
	return MyDual(co, -si * x.deriv)
end

# ╔═╡ 1745325b-7779-4ef6-b814-e28b95d3c2bf
cos(MyDual(π, 1))

# ╔═╡ c5837698-a27d-4ba2-815a-c4ab57f7987b
function Base.exp(x::MyDual)
	e = exp(x.value)
	return MyDual(e, e * x.deriv)
end

# ╔═╡ 43a3be14-e23a-474f-9f87-b1a8eb29a3c2
@bind f_diff Select([
	sin => "f(x) = sin(x)",
	cos => "f(x) = cos(x)",
	exp => "f(x) = exp(x)",
	(x -> sin(100 * x)) => "f(x) = sin(100 x)",
	(x -> sin(x / 100)) => "f(x) = sin(x / 100)",
])

# ╔═╡ 6421ff3c-9b52-45f2-a4d8-8f3358a56d0d
let
	fig = Figure()
	ax = Axis(fig[1, 1]; 
			  xlabel = L"Step size $h$", 
			  ylabel = "Error of the forward differences",
			  xscale = log10, yscale = log10)
	
	f = f_diff
	x = one(FloatType)
	(f′x,) = autodiff(Forward, f, Duplicated(Float64(x), 1.0))
	h = FloatType.(10.0 .^ range(-20, 0, length = 500))
	fd_error(h) = max(abs((f(x + h) - f(x)) / h - f′x), eps(x) / 100)
	lines!(ax, h, fd_error.(h); label = "")
	
	h_def = sqrt(eps(x))
	scatter!(ax, [h_def], [fd_error(h_def)]; color = :gray)
	text!(ax, "sqrt(eps(x))"; position=(5 * h_def, fd_error(h_def)), space = :data)
	
	fig
end

# ╔═╡ 1498e0c0-4e5b-424a-920c-19b99e750c75
let
	fig = Figure()
	ax = Axis(fig[1, 1]; 
			  xlabel = L"Step size $h$", 
			  ylabel = "Error of the central differences",
			  xscale = log10, yscale = log10)
	
	f = f_diff
	x = one(FloatType)
	(f′x,) = autodiff(Forward, f, Duplicated(Float64(x), 1.0))
	h = FloatType.(10.0 .^ range(-20, 0, length = 500))
	fd_error(h) = max(abs((f(x + h) - f(x - h)) / (2 * h) - f′x), eps(x) / 100)
	lines!(ax, h, fd_error.(h); label = "")
	
	h_def = cbrt(eps(x))
	scatter!(ax, [h_def], [fd_error(h_def)]; color = :gray)
	text!(ax, "cbrt(eps(x))"; position=(5 * h_def, fd_error(h_def)), space = :data)
	
	fig
end

# ╔═╡ c406d7fe-f92b-45ac-86a0-02d6b5142605
f(x) = log(x^2 + exp(sin(x)))

# ╔═╡ 03435083-c0b6-4d10-8326-cae43b55cd4b
f′(x) = 1 / (x^2 + exp(sin(x))) * (2 * x + exp(sin(x)) * cos(x))

# ╔═╡ 926aad9a-9beb-45ab-ad74-796b495e3049
function f_graph(x)
	c1 = x^2
	c2 = sin(x)
	c3 = exp(c2)
	c4 = c1 + c3
	c5 = log(c4)
	return c5
end

# ╔═╡ 9cfb64ed-e004-46e3-bd41-4256127be994
function f_graph_derivative(x)
	c1 = x^2
	c1_ε = 2 * x
	
	c2 = sin(x)
	c2_ε = cos(x)
	
	c3 = exp(c2)
	c3_ε = exp(c2) * c2_ε
	
	c4 = c1 + c3
	c4_ε = c1_ε + c3_ε
	
	c5 = log(c4)
	c5_ε = c4_ε / c4
	return c5, c5_ε
end

# ╔═╡ 33e7313b-9877-4da5-aeeb-9f0fdae7458c
f_graph_derivative(1.0)

# ╔═╡ 47ba60d1-8ce6-45b9-8033-74266d4f32c2
@code_typed f_graph_derivative(1.0)

# ╔═╡ 3c85e394-b093-4888-846a-fb43c90258e3
@benchmark f_graph_derivative($(Ref(1.0))[])

# ╔═╡ 38b0e342-1368-4ddb-867a-467afc725029
exp(MyDual(1.0, 1))

# ╔═╡ 8ac44757-b52a-4c4d-83aa-39f328361dcb
derivative(x -> 3 * x^2 + 4 * x + 5, 2)

# ╔═╡ 7dfdfb02-517d-4d8f-b6da-9f725ddb70b2
derivative(3) do x
	sin(x) * log(x)
end

# ╔═╡ ca134138-cc53-4827-927e-3f8c0b8efe28
g(x, y) = x^2 * y

# ╔═╡ fd4f6aa2-8ba3-4fcd-8d1f-1c9b70f3cacf
function gradient_vector(g, x, y)
	xx = MyMultiDual(x, SVector(1.0, 0.0))
	yy = MyMultiDual(y, SVector(0.0, 1.0))
	g(xx, yy).deriv
end

# ╔═╡ 26912ad7-9de7-4dbd-a07a-27d02288f36d
md"If we want to extend this to vector-valued functions to compute the Jacobian, we just need to apply this technique to each component individually. If we just use derivatives with respect to a single variable, we fill the Jacobian column by column. Again, there are better ways to store variables and handle this (including batching), but this is the basic idea."

# ╔═╡ 0cea9925-12a5-4d24-a7f3-e2fd18659742
md"""
## Forward- vs. reverse-mode AD

What we have discussed above is the basic idea of forward-mode AD. It is called this way since the information of the derivatives propagates in the same way as the usual computation. Let's now consider a typical optimization problem, e.g.,

$$\min_x \| A x - b \|_2^2,$$

where $A$ and $b$ are given. To use something like gradient descent, we need to compute the derivative with respect to $x$, i.e.,

$$\nabla_x \| A x - b \|_2^2 = 2 (A x - b)^T A.$$

Let's check this with a simple example.
"""

# ╔═╡ f4ddde0d-daec-43f8-a130-502fa59526fd
let
	A = [1.0 2.0; 3.0 4.0]
	b = [5.0, 6.0]
	f = (x1, x2) -> begin
		y = A * [x1, x2] - b
		return y[1]^2 + y[2]^2
	end

	x = randn(2)
	result_ad = gradient_scalar(f, x...)
	result = 2 * (A * x - b)' * A
	
	abs2(result_ad[1] - result[1]) + abs2(result_ad[2] - result[2])
end

# ╔═╡ abd5dc0c-ab90-4325-b120-241d1ba344aa
md"""
Next, let's consider a non-square matrix $A$ and set $b = 0$ for simplicity.
Then, we have

$$\nabla_x \| A x \|_2^2 = 2 (A x)^T A = 2 x^T A^T A.$$

If you want to calculate this gradient by hand, you have to choose whether you want to

- first calculate $A^T A$ and then $x^T (A^T A)$
- first calculate $x^T A^T$ and then $(x^T A^T) A$

Which order would you choose?
"""

# ╔═╡ 3ecb117c-1731-4882-91bd-1540f5d57221
order_1(A, x) = x' * (A' * A)

# ╔═╡ 375f8c84-6ebd-49b0-b77b-5ff582b2f174
order_2(A, x) = (x' * A') * A

# ╔═╡ 578c0043-cc0e-406d-8bc0-ce4e3cad6491
md"### $4 \times 4$ matrix"

# ╔═╡ 95f221bb-2a64-4e58-8712-d4c0542c9d49
A1 = randn(4, 4)

# ╔═╡ 6f2aa718-37d4-4f40-b8e8-184271d1e2eb
x1 = randn(size(A1, 2))

# ╔═╡ 0611caea-3f95-4783-bf4d-69e37ee91dce
@benchmark order_1($A1, $x1)

# ╔═╡ 70ddb2ce-98a4-494a-870f-979a0bf7a957
@benchmark order_2($A1, $x1)

# ╔═╡ 946bd01b-3564-4614-ae45-1b9764cc58bc
md"### $2 \times 8$ matrix"

# ╔═╡ 5ab01f73-8828-4ab4-afc4-c9664bc2214d
A3 = randn(2, 8)

# ╔═╡ 0b3207f3-7960-45c9-8cf1-6da745505428
x3 = randn(size(A3, 2))

# ╔═╡ cda52a43-4f4a-4f77-ab52-89cf99e81976
@benchmark order_1($A3, $x3)

# ╔═╡ 80d591c3-9ded-486f-989d-07b541d9f9e8
@benchmark order_2($A3, $x3)

# ╔═╡ bb57dee4-f2bf-4858-82ea-602062aa5ca8
md"""
### General introduction

The difference between these orders is the basic idea of forward- vs. reverse-mode AD. To give you a rough idea, consider the chain rule applied to the function

$$x \mapsto f\Bigl( g\bigl( h(x) \bigr) \Bigr),$$

i.e.,

$$\nabla_x f\Bigl( g\bigl( h(x) ) \bigr) \Bigr) = f'\Bigl( g\bigl( h(x) \bigr) \Bigr) \cdot g'\bigl( h(x) \bigr) \cdot h'(x).$$

Forward-mode AD is like computing the derivatives from right to left like the usual data flow when computing $(f \circ g \circ h)(x)$. In contrast, reverse-mode AD is like computing the derivatives from left to right, i.e., in reverse order. To be able to do so, you need to store the indermediate values $h(x)$ and $g\bigl( h(x) \bigr)$.
"""

# ╔═╡ 556bd85d-e435-40e5-b148-fd31b6c10844
function forward(f, f′, g, g′, h, h′, x)
	h_x = h(x)
	h′_x = h′(x)

	gh_x = g(h_x)
	gh′_x = g′(h_x) * h′_x

	fgh_x = f(gh_x)
	fgh′_x = f′(gh_x) * gh′_x

	return fgh_x, fgh′_x
end

# ╔═╡ db3168d0-12f7-40b4-93be-9bffcb840cb2
function reverse(f, f′, g, g′, h, h′, x)
	h_x = h(x)
	gh_x = g(h_x)
	fgh_x = f(gh_x)

	f′_ghx = f′(gh_x)
	fg′_hx = f′_ghx * g′(h_x)
	fgh′_x = fg′_hx * h′(x)

	return fgh_x, fgh′_x
end

# ╔═╡ c5f1e8f1-51ea-460f-ac88-16e8d8fb8320
const A = randn(10, 10^2)

# ╔═╡ 81ba7e11-34b0-4e98-8131-387495662588
const b = randn(size(A, 1))

# ╔═╡ 72135823-1565-4ee1-b89d-edf874bc636c
h(x::AbstractVector) = A * x

# ╔═╡ 8287f217-96e8-48fc-a421-e94bb1f8f1af
h′(x::AbstractVector) = A

# ╔═╡ 2f6ebf49-29a6-4553-9102-886f33386441
g(Ax::AbstractVector) = Ax - b

# ╔═╡ 9e9ae189-8bbf-4a15-8c28-b379db4be3ab
gradient_scalar(g, 1.0, 2.0)

# ╔═╡ 378d2e4f-c121-48c3-814c-cb6b57854000
gradient_vector(g, 1.0, 2.0)

# ╔═╡ 1bc014cd-66aa-48ca-ac41-cb94cbaf31c6
g′(Ax::AbstractVector) = I

# ╔═╡ 3dcbcabd-138d-45f8-911a-732217bfe392
f(Ax_b::AbstractVector) = sum(abs2, Ax_b)

# ╔═╡ 4c1c262f-c179-4366-b9e5-d2b3770b4358
f(1.0) ≈ f_graph(1.0)

# ╔═╡ 91796846-fb91-491f-9fa0-3678ddf8e93d
let x = 1.0, h = sqrt(eps())
	(f(x + h) - f(x)) / h
end

# ╔═╡ 375e0d9f-c645-4e46-a587-b23171285864
let
	f_dual = f(MyDual(1.0, 1.0))
	(f_dual.value, f_dual.deriv) .- f_graph_derivative(1.0)
end

# ╔═╡ c10053e1-8cf9-4c57-a048-fcdf1d876ab0
@code_typed f(MyDual(1.0, 1.0))

# ╔═╡ 65b81bf3-5d2c-440e-a624-bd24cf79ee30
@benchmark f(MyDual($(Ref(1.0))[], 1.0))

# ╔═╡ 27d0c7ee-db16-4a6e-9f1e-2fbd29fdf050
derivative(f, 1.0)

# ╔═╡ 815d032c-113d-4aa5-a062-f4276a81d038
f′(Ax_b::AbstractVector) = 2 * Ax_b'

# ╔═╡ 7d68c716-7b2c-407c-98ef-0cae17dff005
(f(1.0), f′(1.0))

# ╔═╡ 7d2bfa4e-5a39-40e6-9543-deed4ed53341
let
	f_dual = f(MyDual(1.0, 1.0))
	(f_dual.value, f_dual.deriv) .- (f(1.0), f′(1.0))
end

# ╔═╡ 7d1e913c-8ca4-45f2-bbc7-904d83bf98fd
let df = derivative(f)
	x = range(0.1, 10.0, length = 10)
	df.(x) - f′.(x)
end

# ╔═╡ 41c7c37b-607c-4243-ac0e-b0ed20e6ddf2
let
	x = randn(size(A, 2))
	fwd = forward(f, f′, g, g′, h, h′, x)
	rev = reverse(f, f′, g, g′, h, h′, x)
	fwd[1] - rev[1], norm(fwd[2] - rev[2])
end

# ╔═╡ 91d190c1-a7d5-470b-9c29-1287ca8eb513
let
	x = randn(size(A, 2))
	@benchmark forward($f, $f′, $g, $g′, $h, $h′, $x)
end

# ╔═╡ 4af1676f-5124-41c2-9b4f-b06c143159d5
let
	x = randn(size(A, 2))
	@benchmark reverse($f, $f′, $g, $g′, $h, $h′, $x)
end

# ╔═╡ 6eff228a-72f6-4101-9d0f-ab9c3049e06c
md"""
## Further resources

There is a lot of material online about AD (in Julia), e.g.,

- [Enzyme.jl](https://github.com/EnzymeAD/Enzyme.jl)
- [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl)
- [Lecture notes "Advanced Topics from Scientific Computing" by Jürgen Fuhrmann](https://www.wias-berlin.de/people/fuhrmann/AdSciComp-WS2324/)
- [https://dj4earth.github.io/MPE24](https://dj4earth.github.io/MPE24/)
- [A JuliaLabs workshop](https://github.com/JuliaLabs/Workshop-OIST/blob/master/Lecture%203b%20--%20AD%20in%2010%20minutes.ipynb)
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
DoubleFloats = "497a8b3b-efae-58df-a0af-a86822472b78"
Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[compat]
BenchmarkTools = "~1.5.0"
CairoMakie = "~0.12.11"
DoubleFloats = "~1.4.0"
Enzyme = "~0.13.3"
LaTeXStrings = "~1.3.1"
PlutoUI = "~0.7.60"
StaticArrays = "~1.9.7"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.5"
manifest_format = "2.0"
project_hash = "9bc58927ce00ea5854c4bb4337dca7121b5a049d"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "6a55b747d1812e699320963ffde36f1ebdda4099"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.0.4"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdaptivePredicates]]
git-tree-sha1 = "7e651ea8d262d2d74ce75fdf47c4d63c07dba7a6"
uuid = "35492f91-a3bd-45ad-95db-fcad7dcfedb7"
version = "1.2.0"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Automa]]
deps = ["PrecompileTools", "TranscodingStreams"]
git-tree-sha1 = "014bc22d6c400a7703c0f5dc1fdc302440cf88be"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.0.4"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "f1dff6729bc61f4d49e140da1af55dcd1ac97b2f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.5.0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9e2a6b69137e6969bab0152632dcb3bc108c8bdd"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+1"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "7b6ad8c35f4bc3bca8eb78127c8b99719506a5fb"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.0"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Cairo_jll", "Colors", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "4f827b38d3d9ffe6e3b01fbcf866c625fa259ca5"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.12.11"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "009060c9a6168704143100f36ab08f06c2af4642"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.2+1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "3e4b134270b372f2ed4d4d0e936aabaefc1802bc"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b5278586822443594ff615963b0c09755771b3e0"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.26.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelaunayTriangulation]]
deps = ["AdaptivePredicates", "EnumX", "ExactPredicates", "PrecompileTools", "Random"]
git-tree-sha1 = "668bb97ea6df5e654e6288d87d2243591fe68665"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "d7477ecdafb813ddee2ae727afa94e9dcb5f3fb0"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.112"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.DoubleFloats]]
deps = ["GenericLinearAlgebra", "LinearAlgebra", "Polynomials", "Printf", "Quadmath", "Random", "Requires", "SpecialFunctions"]
git-tree-sha1 = "98d485da59c3f9d511429bdcb41b0762bf6ee1d5"
uuid = "497a8b3b-efae-58df-a0af-a86822472b78"
version = "1.4.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.Enzyme]]
deps = ["CEnum", "EnzymeCore", "Enzyme_jll", "GPUCompiler", "LLVM", "Libdl", "LinearAlgebra", "ObjectFile", "Preferences", "Printf", "Random"]
git-tree-sha1 = "35ff0eb8afbb319a9a38bd3a1cf0d3264655a9b8"
uuid = "7da242da-08ed-463a-9acd-ee780be4f1d9"
version = "0.13.3"

    [deps.Enzyme.extensions]
    EnzymeBFloat16sExt = "BFloat16s"
    EnzymeChainRulesCoreExt = "ChainRulesCore"
    EnzymeLogExpFunctionsExt = "LogExpFunctions"
    EnzymeSpecialFunctionsExt = "SpecialFunctions"
    EnzymeStaticArraysExt = "StaticArrays"

    [deps.Enzyme.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    LogExpFunctions = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.EnzymeCore]]
git-tree-sha1 = "2821c1873ab5f7dbfc30e4ba2a8e0f30c13c883a"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.2"
weakdeps = ["Adapt"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"

[[deps.Enzyme_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "4f444c4c6ed28b8501a3749ac474098329a5310e"
uuid = "7cc45869-7501-5eee-bdea-0790c847d4ef"
version = "0.0.150+0"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "b3f2ff58735b5f024c392fde763f29b057e4b025"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.8"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c6317308b9dc757616f0b5cb379db10494443a7"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.2+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Extents]]
git-tree-sha1 = "81023caa0021a41712685887db1fc03db26f41f5"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.4"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "8cc47f299902e13f90405ddb5bf87e5d474c0d38"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "6.1.2+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "4820348781ae578893311153d69049a93d05f39d"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.8.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4d81ed14783ec49ce9f2e168208a12ce1815aa25"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "82d8afa92ecf4b52d78d869f038ebfb881267322"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.3"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "7878ff7172a8e6beedd1dea14bd27c3c6340d361"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.22"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "db16beca600632c95fc8aca29890d83788dd8b23"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.96+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "5c1d8ae0efc6c2e7b1fc502cbe25def8f661b7bc"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.2+0"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "2493cdfd0740015955a8e46de4ef28f49460d8bc"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.3"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1ed150b39aebcc805c26b93a8d0122c940f64ce2"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.14+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "PrecompileTools", "Preferences", "Scratch", "Serialization", "TOML", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "1d6f290a5eb1201cd63574fbc4440c788d5cb38f"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.27.8"

[[deps.GenericLinearAlgebra]]
deps = ["LinearAlgebra", "Printf", "Random", "libblastrampoline_jll"]
git-tree-sha1 = "02be7066f936af6b04669f7c370a31af9036c440"
uuid = "14197337-ba66-59df-a3e3-ca00e7dcff7a"
version = "0.3.11"

[[deps.GeoFormatTypes]]
git-tree-sha1 = "59107c179a586f0fe667024c5eb7033e81333271"
uuid = "68eda718-8dee-11e9-39e7-89f7f65f511f"
version = "0.4.2"

[[deps.GeoInterface]]
deps = ["Extents", "GeoFormatTypes"]
git-tree-sha1 = "2f6fce56cdb8373637a6614e14a5768a88450de2"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.3.7"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "Extents", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "b62f2b2d76cee0d61a2ef2b3118cd2a3215d3134"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.11"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "674ff0db93fffcd11a3573986e550d66cd4fd71f"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.80.5+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "fc713f007cff99ff9e50accba6373624ddd33588"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "401e4f3f30f43af2c8478fc008da50096ea5240f"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.3.1+0"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "7c4195be1649ae622304031ed46a2f4df989f1eb"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.24"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "2e4520d67b0cef90865b3ef727594d2a58e0e1f8"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.11"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "b2a7eaa169c13f5bcae8131a83bc30eff8f71be0"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.2"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "437abb322a41d527c197fa800455f79d414f0a3c"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.8"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "355e2b974f2e3212a75dfb60519de21361ad3cb7"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.9"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "10bd689145d2c3b2a9844005d01087cc1194e79e"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.2.1+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm_jll", "MacroTools", "RoundingEmulator"]
git-tree-sha1 = "8e125d40cae3a9f4276cdfeb4fcdb1828888a4b3"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.22.17"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"

    [deps.IntervalArithmetic.weakdeps]
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"

[[deps.IntervalSets]]
git-tree-sha1 = "dba9ddf07f77f60450fe5d2e2beb9854d9a49bd0"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.10"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "be3dc50a92e5a386872a493a10050136d4703f9b"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "fa6d0bcff8583bac20f1ffa708c3913ca605c611"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.5"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "25ee0be4d43d0269027024d75a24c24d6c6e590c"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.4+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "7d703202e65efa1369de1279c162b915e245eed1"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.9"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "170b660facf5df5de098d866564877e119141cbd"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.2+0"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Preferences", "Printf", "Requires", "Unicode"]
git-tree-sha1 = "4ad43cb0a4bb5e5b1506e1d1f48646d7e0c80363"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.1.2"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "05a8bd5a42309a9ec82f700876903abce1017dd3"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.34+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "78211fb6cbc872f77cad3fc0b6cf647d923f4929"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.7+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "854a9c268c43b77b0a27f22d7fab8d33cdb3a731"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.2+1"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "9fd170c4bbfd8b935fdc5f8b7aa33532c991a673"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.11+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fbb1f2bef882392312feb1ede3615ddc1e9b99ed"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.49.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0c4f9c4f1a50d8f35048fa0532dabbadf702f81e"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.40.1+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "5ee6203157c120d79034c748a2acba45b82b8807"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.40.1+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "f046ccd0c6db2832a9f639e2c669c6fe867e5f4f"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.2.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "MakieCore", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "2281aaf0685e5e8a559982d32f17d617a949b9cd"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.21.11"

[[deps.MakieCore]]
deps = ["ColorTypes", "GeometryBasics", "IntervalSets", "Observables"]
git-tree-sha1 = "22fed09860ca73537a36d4e5a9bce0d9e80ee8a8"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.8.8"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "e1641f32ae592e415e3dbae7f4a188b5316d4b62"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.1"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.ObjectFile]]
deps = ["Reexport", "StructIO"]
git-tree-sha1 = "7249afa1c4dfd86bfbcc9b28939ab6ef844f4e11"
uuid = "d8793406-e978-5875-9003-1fc021f44a92"
version = "0.4.2"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "1a27764e945a152f7ca7efa04de513d473e9542e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.14.1"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+1"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6703a85cb3781bd5909d48730a67205f3f31a575"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.3+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "949347156c25054de2db3b166c52ac4728cbad65"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.31"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "67186a2bc9a90f9f85ff3cc8277868961fb57cbd"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.3"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "ec3edfe723df33528e085e632414499f26650501"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.0"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e127b609fb9ecba6f201ba7ab753d5a605d53801"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.54.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "35621f10a7531bc8fa58f74610b1bfb70a3cfc6b"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.43.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "7b1a9df27f072ac4c9c7cbe5efb198489258d1f5"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.1"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eba4810d5e6a01f612b948c9fa94f905b49087b0"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.60"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "RecipesBase", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "1a9cfb2dc2c2f1bd63f1906d72af39a79b49b736"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "4.0.11"

    [deps.Polynomials.extensions]
    PolynomialsChainRulesCoreExt = "ChainRulesCore"
    PolynomialsFFTWExt = "FFTW"
    PolynomialsMakieCoreExt = "MakieCore"
    PolynomialsMutableArithmeticsExt = "MutableArithmetics"

    [deps.Polynomials.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
    MakieCore = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
    MutableArithmetics = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "8f6bc219586aef8baf0ff9a5fe16ee9c70cb65e4"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.2"

[[deps.PtrArrays]]
git-tree-sha1 = "77a42d78b6a92df47ab37e177b2deac405e1c88f"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.2.1"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "cda3b045cf9ef07a08ad46731f5a3165e56cf3da"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.1"
weakdeps = ["Enzyme"]

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

[[deps.Quadmath]]
deps = ["Compat", "Printf", "Random", "Requires"]
git-tree-sha1 = "67fe599f02c3f7be5d97310674cd05429d6f1b42"
uuid = "be4d8f0f-7fa4-5f49-b795-2f01399ab2dd"
version = "0.5.10"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "852bd0f55565a9e973fcfee83a84413270224dc4"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.8.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "98ca7c29edd6fc79cd74c61accb7010a4e7aee33"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.6.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "79123bc60c5507f035e6d1d9e563bb2971954ec8"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.4.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "2da10356e31327c7096832eb9cd86307a50b1eb6"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "2f5d4697f21388cbe1ff299430dd169ef97d7e14"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.4.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "eeafab08ae20c62c44c8399ccb9354a04b80db50"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.7"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "b423576adc27097764a90e163157bcfc9acf0f46"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.2"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "f4dc295e983502292c4c3f951dbb4e985e35b3be"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.18"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = "GPUArraysCore"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StructIO]]
git-tree-sha1 = "c581be48ae1cbf83e899b14c07a807e1787512cc"
uuid = "53d494c1-5632-5724-8f4c-31dff12d585f"
version = "0.3.1"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "bc7fd5c91041f44636b2c134041f7e5263ce58ae"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.10.0"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "3a6f063d690135f5c1ba351412c82bae4d1402bf"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.25"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "d95fe458f26209c66a187b1114df96fd70839efd"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.21.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "1165b0443d0eca63ac1e32b8c0eb69ed2f4f8127"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "a54ee957f4c86b526460a720dbc882fa5edcbefc"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.41+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "afead5aba5aa507ad5a3bf01f58f82c8d1403495"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6035850dcc70518ca32f012e46015b9beeda49d8"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "34d526d318358a859d7de23da945578e8e8727b7"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d2d1a5c49fae4ba39983f63de6afcbea47194e85"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "47e45cd78224c53109495b3e324df0c37bb61fbe"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.11+0"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8fdda4c692503d44d04a0603d9ac0982054635f9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "bcd466676fef0878338c61e655629fa7bbc69d8e"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e92a1a012a10506618f10b7047e478403a046c77"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1827acba325fdcdf1d2647fc8d5301dd9ba43a9d"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.9.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e17c115d55c5fbb7e52ebedb427a0dca79d4484e"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a22cf860a7d27e4f3498a0fe0811a7957badb38"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.3+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d7015d2e18a5fd9a4f47de711837e980519781a4"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.43+1"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "libpng_jll"]
git-tree-sha1 = "7dfa0fd9c783d3d0cc43ea1af53d69ba45c447df"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.3+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "490376214c4721cdaca654041f635213c6165cb3"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+2"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "35976a1216d6c066ea32cba2150c4fa682b276fc"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.0+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc541bb19ed5b0ede95581fb2e41ecf179527d2"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.6.0+0"
"""

# ╔═╡ Cell order:
# ╟─3df9311e-92a0-11ef-3b43-d9393641d811
# ╟─b3ae7754-8839-479b-8134-bca0a66aa294
# ╠═fcd42a91-52bb-472a-bdf5-1dc6dc88746a
# ╠═fca087a8-babf-4115-ace8-ac9f4d357684
# ╠═01e58263-94b8-4685-a7d7-48d2eb0d5ab3
# ╠═65b90601-fa37-448a-a9d3-6fcee665d791
# ╠═6fcc36b0-7845-4c19-83f5-35c0ffbd9c66
# ╠═4550d944-23dd-45af-a4c2-356b8a0be13a
# ╠═5a1bf2d0-d67f-4157-8095-d8a458431a6a
# ╠═91df7c2f-c6d6-4c45-b965-0ff13c17434c
# ╟─23c7e21c-1f58-4a43-9a18-f4d0360e0abc
# ╠═151d76cf-a1ce-4b64-9661-b34ed516dd30
# ╠═028d57c4-0ebc-4359-888d-65ecd080fe0f
# ╠═702c0ce9-aa9c-4240-a8fb-b492a431b180
# ╠═bbf4cecf-64c8-47c6-9f27-dbebbc59843a
# ╠═88602567-bbc3-4244-91b7-78f11087fcce
# ╟─7d9ad4f0-33ea-4afb-8834-3d3a6645a4ee
# ╟─43a3be14-e23a-474f-9f87-b1a8eb29a3c2
# ╟─22832ba3-257f-4daa-b8eb-5ea6094b50c7
# ╟─6421ff3c-9b52-45f2-a4d8-8f3358a56d0d
# ╟─ab64c9c0-5177-45c8-8422-8f09f84af990
# ╟─1498e0c0-4e5b-424a-920c-19b99e750c75
# ╟─f8ee1a92-208f-4558-a797-aca82c272804
# ╠═c406d7fe-f92b-45ac-86a0-02d6b5142605
# ╟─a1666545-2256-4015-bee8-2b6a80693ea3
# ╠═03435083-c0b6-4d10-8326-cae43b55cd4b
# ╟─33b67c04-8e28-4361-a572-6379f3a69ac0
# ╠═926aad9a-9beb-45ab-ad74-796b495e3049
# ╠═4c1c262f-c179-4366-b9e5-d2b3770b4358
# ╟─190fc532-f613-4226-9553-ecae2dc08614
# ╠═9cfb64ed-e004-46e3-bd41-4256127be994
# ╠═33e7313b-9877-4da5-aeeb-9f0fdae7458c
# ╠═7d68c716-7b2c-407c-98ef-0cae17dff005
# ╠═91796846-fb91-491f-9fa0-3678ddf8e93d
# ╟─1811b4ff-f45a-4144-8f67-abddc79c1f1c
# ╠═a8e22d08-c2c8-4ee4-87fe-7b665edc4a3e
# ╟─9367a32a-160f-418b-9938-8e766a77e475
# ╠═d329aecc-4696-4740-9a86-d5da14cce69b
# ╟─9881c9b3-c1df-4e69-827f-a06347240dc5
# ╠═597ac91c-ac82-4281-903e-57d82cd2c79b
# ╠═6b8edf00-d973-4228-9524-86670e4a989a
# ╠═f48aeca4-2833-4571-82fa-dfddfc3f583b
# ╠═1489d2c7-4bd3-49b3-99e2-74ce1e2211ce
# ╠═3c2c092d-2d52-4379-99f0-6ccc2d237668
# ╠═ccf335ff-e40d-4144-8579-81c2c7c1046b
# ╠═4afbb4a3-3630-4e80-90b9-f7d1a946dc43
# ╠═92a7e494-86b5-4d1f-ad6b-622b5f184bfe
# ╟─dab7c717-8980-4f52-b8af-b0d09577771f
# ╠═0dcab12e-8fbd-4b26-902f-00416f29a816
# ╠═4735f5ae-e497-4949-95d9-f90952a47435
# ╠═590f30b1-9c90-4b03-83da-bea3ea92dd60
# ╟─1a5f7311-ec24-4f3a-9d35-d8a636736ed1
# ╠═72922b27-6172-44ca-93bc-e8380b92baca
# ╠═9ce7e5e5-50db-44bb-9642-e6a25fa502f6
# ╠═e79abdd7-cc18-4b7b-bc83-78e0e7cc00b2
# ╠═1745325b-7779-4ef6-b814-e28b95d3c2bf
# ╠═28ae9185-edd2-4df4-a336-2c7face37228
# ╠═b6c470da-2708-4fe7-a95c-eeab90ff9944
# ╠═c5837698-a27d-4ba2-815a-c4ab57f7987b
# ╠═38b0e342-1368-4ddb-867a-467afc725029
# ╟─d89ea840-631c-44e3-8839-9a055a961877
# ╠═7d2bfa4e-5a39-40e6-9543-deed4ed53341
# ╠═375e0d9f-c645-4e46-a587-b23171285864
# ╟─482a3cbc-b4cf-4cbd-aa35-7913d03840fb
# ╠═c10053e1-8cf9-4c57-a048-fcdf1d876ab0
# ╠═47ba60d1-8ce6-45b9-8033-74266d4f32c2
# ╟─4a47abae-0952-4da5-8260-ea35f22697a8
# ╠═3c85e394-b093-4888-846a-fb43c90258e3
# ╠═65b81bf3-5d2c-440e-a624-bd24cf79ee30
# ╟─cdd33aab-4c45-447c-a5a3-79610bb5621a
# ╠═c31eb587-90e3-480a-921d-ebcddd749118
# ╠═27d0c7ee-db16-4a6e-9f1e-2fbd29fdf050
# ╠═8ac44757-b52a-4c4d-83aa-39f328361dcb
# ╠═7dfdfb02-517d-4d8f-b6da-9f725ddb70b2
# ╟─5647fd0e-ce4c-4c54-b6b8-5bdcc4a74cd6
# ╠═07b170ea-1fe4-43ac-b78a-c34e59a55526
# ╠═7d1e913c-8ca4-45f2-bbc7-904d83bf98fd
# ╟─c98748bd-545f-49b6-bb6a-e06dd0719d73
# ╠═ca134138-cc53-4827-927e-3f8c0b8efe28
# ╠═e6809491-e021-4696-bf44-49a9a1936ac4
# ╠═9e9ae189-8bbf-4a15-8c28-b379db4be3ab
# ╟─75cc7eca-1f89-440b-bfd0-5b7624323c65
# ╠═dfd400fa-dafc-4604-8064-ac0c88967965
# ╠═1a764d54-fbf2-431b-8095-82c2d1e3eb8a
# ╠═9b318e2a-8f7f-4350-86b6-0713e1603c42
# ╠═fd4f6aa2-8ba3-4fcd-8d1f-1c9b70f3cacf
# ╠═378d2e4f-c121-48c3-814c-cb6b57854000
# ╟─26912ad7-9de7-4dbd-a07a-27d02288f36d
# ╟─0cea9925-12a5-4d24-a7f3-e2fd18659742
# ╠═f4ddde0d-daec-43f8-a130-502fa59526fd
# ╟─abd5dc0c-ab90-4325-b120-241d1ba344aa
# ╠═3ecb117c-1731-4882-91bd-1540f5d57221
# ╠═375f8c84-6ebd-49b0-b77b-5ff582b2f174
# ╟─578c0043-cc0e-406d-8bc0-ce4e3cad6491
# ╠═95f221bb-2a64-4e58-8712-d4c0542c9d49
# ╠═6f2aa718-37d4-4f40-b8e8-184271d1e2eb
# ╠═0611caea-3f95-4783-bf4d-69e37ee91dce
# ╠═70ddb2ce-98a4-494a-870f-979a0bf7a957
# ╟─946bd01b-3564-4614-ae45-1b9764cc58bc
# ╠═5ab01f73-8828-4ab4-afc4-c9664bc2214d
# ╠═0b3207f3-7960-45c9-8cf1-6da745505428
# ╠═cda52a43-4f4a-4f77-ab52-89cf99e81976
# ╠═80d591c3-9ded-486f-989d-07b541d9f9e8
# ╟─bb57dee4-f2bf-4858-82ea-602062aa5ca8
# ╠═556bd85d-e435-40e5-b148-fd31b6c10844
# ╠═db3168d0-12f7-40b4-93be-9bffcb840cb2
# ╠═c5f1e8f1-51ea-460f-ac88-16e8d8fb8320
# ╠═81ba7e11-34b0-4e98-8131-387495662588
# ╠═72135823-1565-4ee1-b89d-edf874bc636c
# ╠═8287f217-96e8-48fc-a421-e94bb1f8f1af
# ╠═2f6ebf49-29a6-4553-9102-886f33386441
# ╠═1bc014cd-66aa-48ca-ac41-cb94cbaf31c6
# ╠═3dcbcabd-138d-45f8-911a-732217bfe392
# ╠═815d032c-113d-4aa5-a062-f4276a81d038
# ╠═41c7c37b-607c-4243-ac0e-b0ed20e6ddf2
# ╠═91d190c1-a7d5-470b-9c29-1287ca8eb513
# ╠═4af1676f-5124-41c2-9b4f-b06c143159d5
# ╟─6eff228a-72f6-4101-9d0f-ab9c3049e06c
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
