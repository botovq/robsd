. "${EXECDIR}/util.sh"

# shellcheck disable=SC2046
diff_revert "$BSDSRCDIR" $(diff_list "$BUILDDIR" "src.diff")
# shellcheck disable=SC2046
diff_revert "$XSRCDIR" $(diff_list "$BUILDDIR" "xenocara.diff")
