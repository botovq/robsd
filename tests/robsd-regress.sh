portable no

robsd_mock >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"
ROBSDKILL="${EXECDIR}/robsd-kill"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/fail"
	regress "test/hello" obj { "usr.bin/hello" }
	regress "test/root" root parallel no
	regress "test/env" env { "FOO=1" "BAR=2" }
	regress "test/pkg" packages { "quirks" "not-installed" }
	regress "test/target" target "one"
	regress "test/xpass"
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/regress/test/fail"
	cat <<EOF >"${TSHDIR}/regress/test/fail/Makefile"
regress:
	exit 66
obj:
EOF
	mkdir -p "${TSHDIR}/usr.bin/hello"
	cat <<EOF >"${TSHDIR}/usr.bin/hello/Makefile"
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/hello"
	cat <<EOF >"${TSHDIR}/regress/test/hello/Makefile"
regress:
	echo hello >${TSHDIR}/hello
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/root"
	cat <<EOF >"${TSHDIR}/regress/test/root/Makefile"
regress:
	echo SUDO=\${SUDO} >${TSHDIR}/root
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/env"
	cat <<EOF >"${TSHDIR}/regress/test/env/Makefile"
regress:
	echo FOO=\${FOO} BAR=\${BAR} >${TSHDIR}/env
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/pkg"
	cat <<EOF >"${TSHDIR}/regress/test/pkg/Makefile"
regress:

obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/target"
	cat <<EOF >"${TSHDIR}/regress/test/target/Makefile"
one:
	echo target >${TSHDIR}/target

obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/xpass"
	cat <<EOF >"${TSHDIR}/regress/test/xpass/Makefile"
regress:
	echo ==== test ====
	echo UNEXPECTED_PASS

obj:
EOF
	cat <<-EOF >"${BINDIR}/pkg_add"
	#!/bin/sh
	echo "pkg_add \${1}" >>${TSHDIR}/pkg
	# Simulate failure, must be ignored.
	exit 1
	EOF
	chmod u+x "${BINDIR}/pkg_add"

	cat <<-EOF >"${BINDIR}/pkg_delete"
	#!/bin/sh
	echo "pkg_delete \${1}" >>${TSHDIR}/pkg
	# Simulate failure, must be ignored.
	exit 1
	EOF
	chmod u+x "${BINDIR}/pkg_delete"

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" -d >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "${TSHDIR}/hello" <<-EOF
	hello
	EOF
	assert_file - "${TSHDIR}/root" <<-EOF
	SUDO=
	EOF
	assert_file - "${TSHDIR}/env" <<-EOF
	FOO=1 BAR=2
	EOF
	assert_file - "${TSHDIR}/pkg" <<-EOF
	pkg_add not-installed
	pkg_delete not-installed
	pkg_delete -a
	EOF
	assert_file - "${TSHDIR}/target" <<-EOF
	target
	EOF

	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"
	_steps="$(step_path "$_builddir")"
	step_eval -n test/xpass "$_steps"
	if [ "$(step_value exit)" -ne 1 ]; then
		fail "expected test/xpass to exit non-zero"
	fi

	robsd_log_sanitize "${_builddir}/robsd.log"
	assert_file - "${_builddir}/robsd.log" <<-EOF
	robsd-regress: using directory ${_builddir} at step 1
	robsd-regress: step env
	robsd-regress: step pkg-add
	robsd-regress: step cvs
	robsd-regress: step patch
	robsd-regress: step obj
	robsd-regress: step mount
	robsd-regress: step test/fail
	robsd-regress: parallel jobs I/N
	robsd-regress: step test/hello
	robsd-regress: parallel jobs I/N
	robsd-regress: step test/root
	robsd-regress: parallel barrier I/N
	robsd-regress: step test/env
	robsd-regress: parallel jobs I/N
	robsd-regress: step test/pkg
	robsd-regress: parallel jobs I/N
	robsd-regress: step test/target
	robsd-regress: parallel jobs I/N
	robsd-regress: step test/xpass
	robsd-regress: parallel jobs I/N
	robsd-regress: step umount
	robsd-regress: parallel barrier I/N
	robsd-regress: step revert
	robsd-regress: step pkg-del
	robsd-regress: step dmesg
	robsd-regress: step end
	robsd-regress: trap exit 0
	EOF

	rm "${BINDIR}/pkg_add"
	rm "${BINDIR}/pkg_delete"
fi

if testcase "failure in non-test step"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/nothing"
	EOF
	mkdir "$ROBSDDIR"
	# Make the env step fail.
	cat <<-EOF >"${BINDIR}/df"
	#!/bin/sh
	exit 1
	EOF
	chmod u+x "${BINDIR}/df"

	if PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" -d >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi

	rm "${BINDIR}/df"
fi

if testcase "failure in non-test step, conflicting with test name"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "usr.bin/patch"
	EOF
	mkdir "$ROBSDDIR"
	: >"${TSHDIR}/patch"

	if PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" \
	   -d -S "${TSHDIR}/patch" >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
fi

if testcase "kill"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/sleep"
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/regress/test/sleep"
	cat <<EOF >"${TSHDIR}/regress/test/sleep/Makefile"
regress:
	echo sleep >${TSHDIR}/sleep
	sleep 3600
obj:
EOF
	_exec="${TSHDIR}/robsd-regress-exec"
	cp "$ROBSDEXEC" "$_exec"

	if ! PATH="${BINDIR}:${PATH}" ROBSDEXEC="$_exec" sh "$ROBSDREGRESS" \
	   >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	until [ -e "${TSHDIR}/sleep" ]; do
		sleep .1
	done

	_robsdkill="${TSHDIR}/robsd-regress-kill"
	cp "$ROBSDKILL" "$_robsdkill"
	PATH="${BINDIR}:${PATH}" ROBSDEXEC="$_exec" sh "$_robsdkill"
	while pgrep -q -f "${ROBSDREGRESS}$"; do
		sleep .1
	done

	echo sleep | assert_file - "${TSHDIR}/sleep"
	if [ -e "${ROBSDDIR}/.running" ]; then
		fail "expected lock to not be present"
	fi
fi
