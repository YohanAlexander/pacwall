#!/bin/bash
set -e

# Default colors.
BACKGROUND='#282a36'
NODE='#ff5555'
ENODE='#ffb86c'
EDGE='#f8f8f2'
GSIZE="1366x768"

OUTPUT="pacwall.png"

STARTDIR="${PWD}"
WORKDIR="/tmp"

prepare() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/"{stripped,raw}
    touch "${WORKDIR}/pkgcolors"
    cd "${WORKDIR}"
}

cleanup() {
    cd "${STARTDIR}" && rm -rf "${WORKDIR}"
}

generate_graph() {
    # Get a space-separated list of the explicitly installed packages.
    EPKGS="$(apt-mark showmanual | tr '\n' ' ')"
    EPKGS=($EPKGS)
    echo "Total explicitly installed packages: ${#EPKGS[@]}"
    for package in ${!EPKGS[@]}
    do

        echo "Package $package: ${EPKGS[package]}"

        # Mark each explicitly installed package using a distinct solid color.
        echo "\"${EPKGS[package]}\" [color=$ENODE]" >> pkgcolors

        # Extract the list of edges from the output of pactree.
        if(!(debtree "${EPKGS[package]}" > "raw/${EPKGS[package]}")) then
        sed -E \
            -e '/START/d' \
            -e '/^node/d' \
            -e '/\}/d' \
            -e '/arrowhead=none/d' \
            -e 's/\[.*\]//' \
            -e 's/>?=.*" ->/"->/' \
            -e 's/>?=.*"/"/' \
            "raw/${EPKGS[package]}" > "stripped/${EPKGS[package]}"
        else
            continue
        fi

    done
}

compile_graph() {
    # Compile the file in DOT languge.
    # The graph is directed and strict (doesn't contain any edge duplicates).
    cd stripped
    echo 'strict digraph G {' > ../pacwall.gv
    cat ../pkgcolors ${EPKGS} >> ../pacwall.gv
    echo '}' >> ../pacwall.gv
    cd ..
}

render_graph() {
    # Style the graph according to preferences.
    declare -a twopi_args=(
        '-Tpng' 'pacwall.gv'
        "-Gbgcolor=${BACKGROUND}"
        "-Ecolor=${EDGE}"
        "-Ncolor=${NODE}"
        '-Nshape=point'
        '-Nheight=0.1'
        '-Nwidth=0.1'
        '-Earrowhead=normal'
    )

    # Optional arguments
    if [ -n "${GSIZE}" ]; then
        twopi_args+=("-Gsize=${GSIZE}")
    fi

    twopi "${twopi_args[@]}" > "${OUTPUT}"
}

resize_wallpaper() {
    # Use imagemagick to resize the image to the size of the screen.
    SCREEN_SIZE=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
    convert "${OUTPUT}" \
        -gravity center \
        -background "${BACKGROUND}" \
        -extent "${SCREEN_SIZE}" \
        "${OUTPUT}"
}

set_wallpaper() {
    set +e
    gsettings set org.gnome.desktop.background picture-uri "${STARTDIR}/${OUTPUT}" \
        2> /dev/null && echo 'Set the wallpaper using gsettings.'
    feh --bg-center --no-fehbg "${STARTDIR}/${OUTPUT}" \
        2> /dev/null && echo 'Set the wallpaper using feh.'
    set -e
}

main() {
    echo 'Preparing the environment'
    prepare

    echo 'Generating the graph.'
    generate_graph 2> /dev/null

    echo 'Compiling the graph.'
    compile_graph

    echo 'Rendering it.'
    render_graph

    resize_wallpaper

    cp "${WORKDIR}/${OUTPUT}" "${STARTDIR}"

    set_wallpaper

    cleanup

    echo 'The image has been put into the current directory.'
    echo 'Done.'
}

help() {
    printf "%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n" \
        "USAGE: $0" \
        "[ -b BACKGROUND ]" \
        "[ -d NODE_COLOR ]" \
        "[ -e EXPLICIT_NODE_COLOR ]" \
        "[ -s EDGE_COLOR ]" \
        "[ -g GSIZE ]" \
        "[ -o OUTPUT ]"
        exit 0
}

options=':b:d:s:e:g:o:h'
while getopts $options option
do
    case $option in
        b  ) BACKGROUND=${OPTARG};;
        d  ) NODE=${OPTARG};;
        e  ) ENODE=${OPTARG};;
        s  ) EDGE=${OPTARG};;
        g  ) GSIZE=${OPTARG};;
        o  ) OUTPUT=${OPTARG};;
        h  ) help;;
        \? ) echo "Unknown option: -${OPTARG}" >&2; exit 1;;
        :  ) echo "Missing option argument for -${OPTARG}" >&2; exit 1;;
        *  ) echo "Unimplemented option: -${OPTARG}" >&2; exit 1;;
    esac
done

shift $((OPTIND - 1))

main
