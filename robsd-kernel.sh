. "${EXECDIR}/util.sh"

kernel_path() {
	local _n _s

	_n="$(sysctl -n hw.ncpu)"
	_s="$(test "$_n" -gt 1 && echo '.MP')"

	printf 'arch/%s/compile/GENERIC%s\n' "$(machine)" "$_s"
}

cd "${BSDSRCDIR}/sys/$(kernel_path)"
make obj
make config
make
make install