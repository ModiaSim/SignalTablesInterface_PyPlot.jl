module Runtests_PyPlot

import SignalTables
using  SignalTables.Test

@testset "Test SignalTablesInterface_PyPlot/test" begin
    SignalTables.usePlotPackage("PyPlot")
    include("$(SignalTables.path)/test/include_all.jl")
    SignalTables.usePreviousPlotPackage()
end

end