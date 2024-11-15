push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using BenchmarkTools
using CUDA
using Oceananigans
using Oceananigans.Advection
using Benchmarks

# Benchmark function

function benchmark_advection_scheme(Arch, Scheme, order)
    grid = RectilinearGrid(Arch(); size=(192, 192, 192), extent=(1, 1, 1))
    order = Scheme == Centered ? order + 1 : order
    model = NonhydrostaticModel(grid=grid, advection=Scheme(; order))

    time_step!(model, 1) # warmup

    trial = @benchmark begin
        @sync_gpu time_step!($model, 1)
    end samples=10

    return trial
end

# Benchmark parameters

Architectures = has_cuda() ? [CPU, GPU] : [CPU]
Schemes = (Centered, UpwindBiased, WENO)
orders  = (1, 3, 5, 7, 9)

# Run and summarize benchmarks

print_system_info()
suite = run_benchmarks(benchmark_advection_scheme; Architectures, Schemes, orders)

df = benchmarks_dataframe(suite)
sort!(df, [:Architectures, :Schemes], by=string)
benchmarks_pretty_table(df, title="Advection scheme benchmarks")

if GPU in Architectures
    df_Δ = gpu_speedups_suite(suite) |> speedups_dataframe
    sort!(df_Δ, :Schemes, by=string)
    benchmarks_pretty_table(df_Δ, title="Advection schemes CPU to GPU speedup")
end

for Arch in Architectures
    suite_arch = speedups_suite(suite[@tagged Arch], base_case=(Arch, Centered))
    df_arch = speedups_dataframe(suite_arch, slowdown=true)
    sort!(df_arch, :Schemes, by=string)
    benchmarks_pretty_table(df_arch, title="Advection schemes relative performance ($Arch)")
end
