portable no

# default_steps
default_steps() {
	step_serialize -s 1 -n one
	step_serialize -H -s 2 -n two
}

if testcase "positive offset"; then
	default_steps >"$TMP1"

	step_eval 1 "$TMP1"
	assert_eq "8" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"

	step_eval 2 "$TMP1"
	assert_eq "8" "${#_STEP[*]}" "two: array length"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"
fi

if testcase "negative offset"; then
	default_steps >"$TMP1"

	step_eval -1 "$TMP1"
	assert_eq "8" "${#_STEP[*]}" "two: array length"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"

	step_eval -2 "$TMP1"
	assert_eq "8" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi

if testcase "name"; then
	default_steps >"$TMP1"

	step_eval -n one "$TMP1"
	assert_eq "8" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi
