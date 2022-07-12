module SignalTablesInterface_PyPlot

# License for this file: MIT (expat)
# Copyright 2017-2022, DLR Institute of System Dynamics and Control

# ToDo:
# MatplotlibDeprecationWarning: Adding an axes using the same arguments as a previous axes currently
# reuses the earlier instance.  In a future version, a new instance will always be created and returned.
# Meanwhile, this warning can be suppressed, and the future behavior ensured, by passing a unique label to each axes instance.
#
# Description how to get rid of the warning:
# https://stackoverflow.com/questions/46933824/matplotlib-adding-an-axes-using-the-same-arguments-as-a-previous-axes#
#
#    ax1 = subplot(..)
#    plot(..)
#    subplot(ax1)   # plot into this previously defined subplot
#    plot(..)
# However, SignalTables.plot(..) has no internal state and has currently now way to pass the ax1 definition to the next SignalTables.plot(..) call.



# It seems that rcParams settings has only an effect, when set on PyPlot in Main
using  SignalTables
import Measurements
import MonteCarloMeasurements

# Determine whether pmean, pmaximum, pminimum is available (MonteCarlMeasurements, version >= 1.0)
const pfunctionsDefined = isdefined(MonteCarloMeasurements, :pmean)

using  Unitful

import PyCall
import PyPlot

export plot, showFigure, saveFigure, closeFigure, closeAllFigures


set_matplotlib_rcParams!(args...) =
   merge!(PyCall.PyDict(PyPlot.matplotlib."rcParams"), Dict(args...))


include("$(SignalTables.path)/src/AbstractPlotInterface.jl")

function setAxisLimits(x)
    delta = x[end] - x[1]
    extra = 0.02*delta
    xmin  = x[1]-extra
    xmax  = x[end]+extra
    if !isnan(xmin) && !isnan(xmax)
        #println("delta = $delta, xmin=$xmin, xmax=$xmax")
        PyPlot.xlim(xmin,xmax)
    end
end

function plotOneSignal(xsig, ysig, ysigType, label, MonteCarloAsArea)
    xsig2 = ustrip.(xsig)
    ysig2 = ustrip.(ysig)
	if typeof(ysig2[1]) <: Measurements.Measurement
		# Plot mean value signal
		xsig_mean = Measurements.value.(xsig2)
		ysig_mean = Measurements.value.(ysig2)
		curve = PyPlot.plot(xsig_mean, ysig_mean, label=label)

		# Plot area of uncertainty around mean value signal (use the same color, but transparent)
		color = PyPlot.matplotlib.lines.Line2D.get_color(curve[1])
		rgba  = PyPlot.matplotlib.colors.to_rgba(color)
		rgba2 = (rgba[1], rgba[2], rgba[3], 0.2)
		ysig_u   = Measurements.uncertainty.(ysig2)
		ysig_max = ysig_mean + ysig_u
		ysig_min = ysig_mean - ysig_u
		PyPlot.fill_between(xsig_mean, ysig_min, ysig_max, color=rgba2)
        setAxisLimits(xsig_mean)

    elseif typeof(ysig2[1]) <: MonteCarloMeasurements.StaticParticles ||
           typeof(ysig2[1]) <: MonteCarloMeasurements.Particles
		# Plot mean value signal
        if pfunctionsDefined
            # MonteCarlMeasurements, version >= 1.0
            xsig_mean = MonteCarloMeasurements.pmean.(xsig2)
            ysig_mean = MonteCarloMeasurements.pmean.(ysig2)
        else
            # MonteCarloMeasurements, version < 1.0
            xsig_mean = MonteCarloMeasurements.mean.(xsig2)
            ysig_mean = MonteCarloMeasurements.mean.(ysig2)
        end
        xsig_mean = ustrip.(xsig_mean)
        ysig_mean = ustrip.(ysig_mean)
		curve = PyPlot.plot(xsig_mean, ysig_mean, label=label)
        color = PyPlot.matplotlib.lines.Line2D.get_color(curve[1])
        rgba  = PyPlot.matplotlib.colors.to_rgba(color)

        if MonteCarloAsArea
            # Plot area of uncertainty around mean value signal (use the same color, but transparent)
    		rgba2 = (rgba[1], rgba[2], rgba[3], 0.2)
            if pfunctionsDefined
                # MonteCarlMeasurements, version >= 1.0
                ysig_max = MonteCarloMeasurements.pmaximum.(ysig2)
                ysig_min = MonteCarloMeasurements.pminimum.(ysig2)
            else
                # MonteCarloMeasurements, version < 1.0
                ysig_max = MonteCarloMeasurements.maximum.(ysig2)
                ysig_min = MonteCarloMeasurements.minimum.(ysig2)
            end
            ysig_max = ustrip.(ysig_max)
            ysig_min = ustrip.(ysig_min)
    		PyPlot.fill_between(xsig_mean, ysig_min, ysig_max, color=rgba2)
            setAxisLimits(xsig_mean)
        else
            # Plot all particle signals (use the same color, but transparent)
    		rgba2 = (rgba[1], rgba[2], rgba[3], 0.1)
            value = ysig[1].particles
            ysig3 = zeros(eltype(value), length(xsig))
            for j in 1:length(value)
                for i in eachindex(ysig)
                    ysig3[i] = ysig[i].particles[j]
                end
                ysig3 = ustrip.(ysig3)
                PyPlot.plot(xsig, ysig3, color=rgba2)
            end
            setAxisLimits(xsig)
        end

	else
        if typeof(xsig2[1]) <: Measurements.Measurement
            xsig2 = Measurements.value.(xsig2)
        elseif typeof(xsig2[1]) <: MonteCarloMeasurements.StaticParticles ||
               typeof(xsig2[1]) <: MonteCarloMeasurements.Particles
            if pfunctionsDefined
                # MonteCarlMeasurements, version >= 1.0
                xsig2 = MonteCarloMeasurements.pmean.(xsig2)
            else
                # MonteCarlMeasurements, version < 1.0
                xsig2 = MonteCarloMeasurements.mean.(xsig2)
            end
            xsig2 = ustrip.(xsig2)
        end
        if ysigType == SignalTables.Continuous
            PyPlot.plot(xsig2, ysig2, label=label)
        else # SignalTables.Clocked
            PyPlot.plot(xsig2, ysig2, ".", label=label)
        end
        if length(xsig2) > 1
            setAxisLimits(xsig2)
        end
	end
end



"""
    addPlot(names, sigTable, grid, xLabel, xAxis, prefix, reuse, maxLegend, MonteCarloAsArea, figure, i, j, nsubFigures)

Add the time series of one name (if names is one symbol/string) or with
several names (if names is a tuple of symbols/strings) to the current diagram
"""
function addPlot(collectionOfNames::Tuple, sigTable, grid::Bool, xLabel::Bool, xAxis, prefix::AbstractString, reuse::Bool, maxLegend::Integer,
                 MonteCarloAsArea::Bool, figure::Int, i::Int, j::Int, nsubFigures::Int)
    xsigLegend = ""
    nLegend = 0

    for name in collectionOfNames
        name2 = string(name)
        (xsig, xsigLegend, ysig, ysigLegend, ysigType) = SignalTables.getPlotSignal(sigTable, name2; xsigName = xAxis)
        if !isnothing(xsig)
            nLegend = nLegend + length(ysigLegend)
            if ndims(ysig) == 1
				plotOneSignal(xsig, ysig, ysigType, prefix*ysigLegend[1], MonteCarloAsArea)
            else
                for i = 1:size(ysig,2)
					plotOneSignal(xsig, ysig[:,i], ysigType, prefix*ysigLegend[i], MonteCarloAsArea)
                end
            end
        end
    end

    PyPlot.grid(grid)
    if nLegend <= maxLegend
        PyPlot.legend()
    elseif nsubFigures == 1
        @info "plot(..): No legend in figure $figure, since curve number (= $nLegend) > maxLegend (= $maxLegend)\nCan be fixed by plot(..., maxLegend=$nLegend)"
    else
        @info "plot(..): No legend in subfigure ($i,$j) of figure $figure, since curve number (= $nLegend) > maxLegend (= $maxLegend)\nCan be fixed by plot(..., maxLegend=$nLegend)"
    end

    if xLabel && !reuse && xsigLegend !== nothing
        PyPlot.xlabel(xsigLegend)
    end
end

addPlot(name::AbstractString, args...) = addPlot((name,)        , args...)
addPlot(name::Symbol        , args...) = addPlot((string(name),), args...)



#--------------------------- Plot function
function plot(sigTable, names::AbstractMatrix; heading::AbstractString="", grid::Bool=true, xAxis=nothing,
              figure::Int=1, prefix::AbstractString="", reuse::Bool=false, maxLegend::Integer=10,
              minXaxisTickLabels::Bool=false, MonteCarloAsArea=false)

    set_matplotlib_rcParams!("axes.formatter.limits" => [-3,4],
                             "font.size"        => 8.0,
                             "lines.linewidth"  => 1.0,
                             "grid.linewidth"   => 0.5,
                             "axes.grid"        => true,
                             "axes.titlesize"   => "medium",
                             "figure.titlesize" => "medium")

    PyPlot.pygui(true) # Use separate plot windows (no inline plots)


    if isnothing(sigTable)
        @info "The call of SignalTables.plot(sigTable, ...) is ignored, since the first argument is nothing."
        return
    end
    xAxis2 = isnothing(xAxis) ? xAxis : string(xAxis)
    PyPlot.figure(figure)
    if !reuse
       PyPlot.clf()
    end
    heading2 = getHeading(sigTable, heading)
    (nrow, ncol) = size(names)

    # Add signals
    k = 1
    for i = 1:nrow
        xLabel = i == nrow
        for j = 1:ncol
            # "reuse" gives a warning
            # MatplotlibDeprecationWarning: Adding an axes using the same arguments as a previous axes currently reuses the earlier instance.  In a future version, a new instance will always be created and returned.  Meanwhile, this warning can be suppressed, and the future behavior ensured, by passing a unique label to each axes instance.
            # One can gid rid of it by the sequence
            #    ax1 = subplot(..)
            #    plot(..)
            #    subplot(ax1)   # plot into this previously defined subplot
            #    plot(..)
            # However, SignalTables.plot(..) has no internal state and has currently now way to pass the ax1 definition to the next SignalTables.plot(..) call.
            ax = PyPlot.subplot(nrow, ncol, k)
            if minXaxisTickLabels && !xLabel
                # Remove xaxis tick labels, if not the last row
                ax.set_xticklabels([])
            end
            addPlot(names[i,j], sigTable, grid, xLabel, xAxis2, prefix, reuse, maxLegend, MonteCarloAsArea, figure, i, j, nrow*ncol)
            k = k + 1
            if ncol == 1 && i == 1 && heading2 != "" && !reuse
                PyPlot.title(heading2)
            end
        end
    end

    # Add overall heading in case of a matrix of diagrams (ncol > 1)
    if ncol > 1 && heading2 != "" && !reuse
        PyPlot.suptitle(heading2)
    end
end

showFigure(figure::Int) = nothing

function saveFigure(figureNumber::Int, fileName)::Nothing
    fullFileName = joinpath(pwd(), fileName)
    println("... save plot in file: \"$fullFileName\"")
    PyPlot.figure(figureNumber)
    PyPlot.savefig(fileName)
    return nothing
end


closeFigure(figure::Int) = PyPlot.close(figure)

closeAllFigures() = PyPlot.close("all")


end
