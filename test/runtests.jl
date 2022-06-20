module Runtests

import SignalTables
using  Test

@testset "Test ModiaPlot_PyPlot/test" begin
    usePlotPackage("PyPlot")
    include("$(SignalTables.path)/test/runtests_withPlot.jl")
    usePreviousPlotPackage()
end

end