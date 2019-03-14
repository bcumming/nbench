#!/usr/bin/env bash

if [ -z "$ns_install_path" -o -z "$ns_build_path" -o -z "$ns_base_path" ]; then
    echo "build_validation_models.sh: missing required ns_ paths" &>2
    exit 1
fi

function try_build_project {
    local src="$1" build="$2" install="$3"

    typeset -x CMAKE_PREFIX_PATH="$ns_install_path:$CMAKE_PREFIX_PATH"

    if [ -e "$build" -a ! -d "$build" ]; then
	echo "File exists at '$build', skipping."
	return 1
    fi

    # Move any existing build directory out of the way.
    if [ -d "$build" ]; then
	local i=1
	while [ -e "$build.$i" ]; do ((++i)); done

	mv "$build" "$build.$i" || {
	    echo "Fatal error: could not move existing build directory '$build'."
	    return 2
	}
    fi

    mkdir -p "$build" || {
	echo "Fatal error: unable to create build directory '$build'."
	return 2
    }

    cd "$build"

    echo "Configuring ${src##*/}."
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH="$install" "$src" &> config.log || {
	echo "Error: refer to log file '$build/config.log'"
    	return 1
    }
    
    echo "Building ${src##*/}."
    make install &> build.log || {
	echo "Error: refer to log file '$build/build.log'"
	return 1
    }
}

# Build any CMake projects living in validation/src/<proj>/.
# If the project has a file BUILDFOR, scan it for patterns
# that match a simulator that has been installed, and only
# attempt to build that project if there is a match.

for ppath in "$ns_base_path"/validation/src/*/CMakeLists.txt; do
    project_dir="${ppath%/*}"
    project_name="${project_dir##*/}"
    build_dir="$ns_build_path/validation/$project_name"

    if [ -r "$project_dir/BUILDFOR" ]; then
	build=
	for pat in $(< $project_dir/BUILDFOR); do
	    [[ $ns_build_arbor == true ]] && [[ arbor == $pat ]] && build=true
	    [[ $ns_build_nest == true ]] && [[ nest == $pat ]] && build=true
	    [[ $ns_build_neuron == true ]] && [[ neuron == $pat ]] && build=true
	    [[ $ns_build_coreneuron == true ]] && [[ coreneuron == $pat ]] && build=true
	done
    else
	build=true
    fi

    if [ -n "$build" ]; then
	try_build_project "$project_dir" "$build_dir" "$ns_install_path"
	if [ $? -gt 1 ]; then exit $?; fi
    fi
done

