using CppCall
using Documenter

DocMeta.setdocmeta!(CppCall, :DocTestSetup, :(using CppCall); recursive=true)

makedocs(;
    modules=[CppCall],
    authors="Yupei Qi <qiyupei@gmail.com> and contributors",
    sitename="CppCall.jl",
    format=Documenter.HTML(;
        canonical="https://Gnimuc.github.io/CppCall.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Gnimuc/CppCall.jl",
    devbranch="main",
)
