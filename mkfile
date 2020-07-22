module=skdds

t/$module.t: $module.nim
    nim c -o:$target $prereq
check:V: t/$module.t
    cd t && ./$module.t

push:V:
    git push github

