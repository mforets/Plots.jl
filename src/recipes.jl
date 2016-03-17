

# TODO: there should be a distinction between an object that will manage a full plot, vs a component of a plot.
# the PlotRecipe as currently implemented is more of a "custom component"
# a recipe should fully describe the plotting command(s) and call them, likewise for updating.
#   actually... maybe those should explicitly derive from AbstractPlot???

abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)

num_series(x::AMat) = size(x,2)
num_series(x) = 1

_apply_recipe(d::Dict; kw...) = ()

# if it's not a recipe, just do nothing and return the args
function _apply_recipe(d::Dict, args...; issubplot=false, kw...)
    if issubplot && !haskey(d, :n) && !haskey(d, :layout)
        # put in a sensible default
        d[:n] = maximum(map(num_series, args))
    end
    args
end

# # -------------------------------------------------

# function rotate(x::Real, y::Real, θ::Real; center = (0,0))
#   cx = x - center[1]
#   cy = y - center[2]
#   xrot = cx * cos(θ) - cy * sin(θ)
#   yrot = cy * cos(θ) + cx * sin(θ)
#   xrot + center[1], yrot + center[2]
# end

# # -------------------------------------------------

# type EllipseRecipe <: PlotRecipe
#   w::Float64
#   h::Float64
#   x::Float64
#   y::Float64
#   θ::Float64
# end
# EllipseRecipe(w,h,x,y) = EllipseRecipe(w,h,x,y,0)

# # return x,y coords of a rotated ellipse, centered at the origin
# function rotatedEllipse(w, h, x, y, θ, rotθ)
#   # # coord before rotation
#   xpre = w * cos(θ)
#   ypre = h * sin(θ)

#   # rotate and translate
#   r = rotate(xpre, ypre, rotθ)
#   x + r[1], y + r[2]
# end

# function getRecipeXY(ep::EllipseRecipe)
#   x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
#   top = rotate(0, ep.h, ep.θ)
#   right = rotate(ep.w, 0, ep.θ)
#   linex = Float64[top[1], 0, right[1]] + ep.x
#   liney = Float64[top[2], 0, right[2]] + ep.y
#   Any[x, linex], Any[y, liney]
# end

# function getRecipeArgs(ep::EllipseRecipe)
#   [(:line, (3, [:dot :solid], [:red :blue], :path))]
# end

# # -------------------------------------------------


# "Correlation scatter matrix"
# function corrplot{T<:Real,S<:Real}(mat::AMat{T}, corrmat::AMat{S} = cor(mat);
#                                    colors = :redsblues,
#                                    labels = nothing, kw...)
#   m = size(mat,2)
#   centers = Float64[mean(extrema(mat[:,i])) for i in 1:m]

#   # might be a mistake?
#   @assert m <= 20
#   @assert size(corrmat) == (m,m)

#   # create a subplot grid, and a gradient from -1 to 1
#   p = subplot(rand(0,m^2); n=m^2, leg=false, grid=false, kw...)
#   cgrad = ColorGradient(colors, [-1,1])

#   # make all the plots
#   for i in 1:m
#     for j in 1:m
#       idx = p.layout[i,j]
#       plt = p.plts[idx]
#       if i==j
#         # histogram on diagonal
#         histogram!(plt, mat[:,i], c=:black)
#         i > 1 && plot!(plt, yticks = :none)
#       elseif i < j
#         # annotate correlation value in upper triangle
#         mi, mj = centers[i], centers[j]
#         plot!(plt, [mj], [mi],
#                    ann = (mj, mi, text(@sprintf("Corr:\n%0.3f", corrmat[i,j]), 15)),
#                    yticks=:none)
#       else
#         # scatter plots in lower triangle; color determined by correlation
#         c = RGBA(RGB(getColorZ(cgrad, corrmat[i,j])), 0.3)
#         scatter!(plt, mat[:,j], mat[:,i], w=0, ms=3, c=c, smooth=true)
#       end

#       if labels != nothing && length(labels) >= m
#         i == m && xlabel!(plt, string(labels[j]))
#         j == 1 && ylabel!(plt, string(labels[i]))
#       end
#     end
#   end

#   # link the axes
#   subplot!(p, link = (r,c) -> (true, r!=c))
# end


"Sparsity plot... heatmap of non-zero values of a matrix"
function spy{T<:Real}(z::AMat{T}; kw...)
  # I,J,V = findnz(z)
  # heatmap(J, I; leg=false, yflip=true, kw...)
  heatmap(map(zi->float(zi!=0), z); leg=false, yflip=true, kw...)
end

"Adds a+bx... straight line over the current plot"
function abline!(plt::Plot, a, b; kw...)
    plot!(plt, [extrema(plt)...], x -> b + a*x; kw...)
end

abline!(args...; kw...) = abline!(current(), args...; kw...)

# =================================================
# Arc and chord diagrams

"Takes an adjacency matrix and returns source, destiny and weight lists"
function mat2list{T}(mat::AbstractArray{T,2})
    nrow, ncol = size(mat) # rows are sources and columns are destinies

    nosymmetric = !issym(mat) # plots only triu for symmetric matrices
    nosparse = !issparse(mat) # doesn't plot zeros from a sparse matrix

    L = length(mat)

    source  = Array(Int, L)
    destiny = Array(Int, L)
    weight  = Array(T, L)

    idx = 1
    for i in 1:nrow, j in 1:ncol
        value = mat[i, j]
        if !isnan(value) && ( nosparse || value != zero(T) ) # TODO: deal with Nullable

            if i < j
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            elseif nosymmetric && (i > j)
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            end

        end
    end

    resize!(source, idx-1), resize!(destiny, idx-1), resize!(weight, idx-1)
end

# -------------------------------------------------
# Arc Diagram

curvecolor(value, min, max, grad) = getColorZ(grad, (value-min)/(max-min))

"Plots a clockwise arc, from source to destiny, colored by weight"
function arc!(source, destiny, weight, min, max, grad)
    radius = (destiny - source) / 2
    arc = Plots.partialcircle(0, π, 30, radius)
    x, y = Plots.unzip(arc)
    plot!(x .+ radius .+ source,  y, line = (curvecolor(weight, min, max, grad), 0.5, 2), legend=false)
end

"""
`arcdiagram(source, destiny, weight[, grad])`

Plots an arc diagram, form `source` to `destiny` (clockwise), using `weight` to determine the colors.
"""
function arcdiagram(source, destiny, weight; kargs...)

    args = Dict(kargs)
    grad = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))

    if length(source) == length(destiny) == length(weight)

        vertices = unique(vcat(source, destiny))
        sort!(vertices)

        xmin, xmax = extrema(vertices)
        plot(xlim=(xmin - 0.5, xmax + 0.5), legend=false)

        wmin,wmax = extrema(weight)

        for (i, j, value) in zip(source,destiny,weight)
            arc!(i, j, value, wmin, wmax, grad)
        end

        scatter!(vertices, zeros(length(vertices)); legend=false, args...)

    else

        throw(ArgumentError("source, destiny and weight should have the same length"))

    end
end

"""
`arcdiagram(mat[, grad])`

Plots an arc diagram from an adjacency matrix, form rows to columns (clockwise),
using the values on the matrix as weights to determine the colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
"""
arcdiagram{T}(mat::AbstractArray{T,2}; kargs...) = arcdiagram(mat2list(mat)...; kargs...)

# -------------------------------------------------
# Chord diagram

arcshape(θ1, θ2) = Shape(vcat(Plots.partialcircle(θ1, θ2, 15, 1.1),
                            reverse(Plots.partialcircle(θ1, θ2, 15, 0.9))))

colorlist(grad, ::Void) = :darkgray

function colorlist(grad, z)
    zmin, zmax = extrema(z)
    RGBA{Float64}[getColorZ(grad, (zi-zmin)/(zmax-zmin)) for zi in z]'
end

"""
`chorddiagram(source, destiny, weight[, grad, zcolor, group])`

Plots a chord diagram, form `source` to `destiny`,
using `weight` to determine the edge colors using `grad`.
`zcolor` or `group` can be used to determine the node colors.
"""
function chorddiagram(source, destiny, weight; kargs...)

    args=Dict(kargs)
    grad  = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))
    zcolor= pop!(args, :zcolor, nothing)
    group = pop!(args, :group,  nothing)

    if zcolor !== nothing && group !== nothing
        throw(ErrorException("group and zcolor can not be used together."))
    end

    if length(source) == length(destiny) == length(weight)

        plt = plot(xlim=(-2,2), ylim=(-2,2), legend=false, grid=false,
        xticks=nothing, yticks=nothing,
        xlim=(-1.2,1.2), ylim=(-1.2,1.2))

        nodemin, nodemax = extrema(vcat(source, destiny))

        weightmin, weightmax = extrema(weight)

        A  = 1.5π # Filled space
        B  = 0.5π # White space (empirical)

        Δα = A / nodemax
        Δβ = B / nodemax

        δ = Δα  + Δβ

        for i in 1:length(source)
            curve = BezierCurve(P2[ (cos((source[i ]-1)*δ + 0.5Δα), sin((source[i ]-1)*δ + 0.5Δα)), (0,0),
                                    (cos((destiny[i]-1)*δ + 0.5Δα), sin((destiny[i]-1)*δ + 0.5Δα)) ])
            plot!(curve_points(curve), line = (Plots.curvecolor(weight[i], weightmin, weightmax, grad), 1, 1))
        end

        if group === nothing
            c =  colorlist(grad, zcolor)
        elseif length(group) == nodemax

            idx = collect(0:(nodemax-1))

            for g in group
                plot!([arcshape(n*δ, n*δ + Δα) for n in idx[group .== g]]; args...)
            end

            return plt

        else
            throw(ErrorException("group should the ", nodemax, " elements."))
        end

        plot!([arcshape(n*δ, n*δ + Δα) for n in 0:(nodemax-1)]; mc=c, args...)

        return plt

    else
        throw(ArgumentError("source, destiny and weight should have the same length"))
    end
end

"""
`chorddiagram(mat[, grad, zcolor, group])`

Plots a chord diagram from an adjacency matrix,
using the values on the matrix as weights to determine edge colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
`zcolor` or `group` can be used to determine the node colors.
"""
chorddiagram(mat::AbstractMatrix; kargs...) = chorddiagram(mat2list(mat)...; kargs...)
