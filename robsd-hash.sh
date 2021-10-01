. "${EXECDIR}/util.sh"

RELDIR="$(release_dir "$BUILDDIR")"
RELXDIR="$(release_dir -x "$BUILDDIR")"

if [ -e "${RELXDIR}/SHA256" ]; then
	cat "${RELXDIR}/SHA256" >>"${RELDIR}/SHA256"
	rm "${RELXDIR}/SHA256"
fi

if [ -d "$RELXDIR" ]; then
	find "$RELXDIR" -type f -exec mv {} "$RELDIR" \;
	rm -r "$RELXDIR"
fi

cd "$RELDIR"

# Adjust BUILDINFO by setting the date to the start of the build and add id.
{
	date -u -r "$(build_date)" "+Build date: %s - %+"
	echo "Build id: ${BUILDDIR##*/}"
} >BUILDINFO

# Compute missing checksums.
mv SHA256 SHA256.orig
{
	grep -v -e 'install.*' -e BUILDINFO SHA256.orig
	sha256 install* BUILDINFO
} | sort >SHA256
rm SHA256.orig
