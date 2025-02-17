#!/usr/bin/env bash

set -e

test_disappearing_class() {
  git checkout test_expect_failure/disappearing_class/ClassProvider.scala
  bazel build test_expect_failure/disappearing_class:uses_class
  echo -e "package scalarules.test\n\nobject BackgroundNoise{}" > test_expect_failure/disappearing_class/ClassProvider.scala
  set +e
  bazel build test_expect_failure/disappearing_class:uses_class
  RET=$?
  git checkout test_expect_failure/disappearing_class/ClassProvider.scala
  if [ $RET -eq 0 ]; then
    echo "Class caching at play. This should fail"
    exit 1
  fi
  set -e
}

test_transitive_deps() {
  set +e

  bazel build test_expect_failure/transitive/scala_to_scala:d
  if [ $? -eq 0 ]; then
    echo "'bazel build test_expect_failure/transitive/scala_to_scala:d' should have failed."
    exit 1
  fi

  bazel build test_expect_failure/transitive/java_to_scala:d
  if [ $? -eq 0 ]; then
    echo "'bazel build test_expect_failure/transitive/java_to_scala:d' should have failed."
    exit 1
  fi

  bazel build test_expect_failure/transitive/scala_to_java:d
  if [ $? -eq 0 ]; then
    echo "'bazel build test_transitive_deps/scala_to_java:d' should have failed."
    exit 1
  fi

  set -e
  exit 0
}

test_override_javabin() {
  # set the JAVABIN to nonsense
  JAVABIN=/etc/basdf action_should_fail run test:ScalaBinary
}

test_scala_library_suite() {
  action_should_fail build test_expect_failure/scala_library_suite:library_suite_dep_on_children
}

test_expect_failure_with_message() {
  set +e

  expected_message=$1
  test_filter=$2
  test_command=$3

  command="bazel test --nocache_test_results --test_output=streamed ${test_filter} ${test_command}"
  output=$(${command} 2>&1)

  echo ${output} | grep "$expected_message"
  if [ $? -ne 0 ]; then
    echo "'bazel test ${test_command}' should have logged \"${expected_message}\"."
        exit 1
  fi
  if [ "${additional_expected_message}" != "" ]; then
    echo ${output} | grep "$additional_expected_message"
    if [ $? -ne 0 ]; then
      echo "'bazel test ${test_command}' should have logged \"${additional_expected_message}\"."
          exit 1
    fi
  fi

  set -e
}

test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message() {
  set +e

  expected_message=$1
  test_target=$2
  strict_deps_mode=$3
  operator=${4:-"eq"}
  additional_expected_message=${5:-""}

  if [ "${operator}" = "eq" ]; then
    error_message="bazel build of scala_library with missing direct deps should have failed."
  else
    error_message="bazel build of scala_library with missing direct deps should not have failed."
  fi

  command="bazel build ${test_target} ${strict_deps_mode}"

  output=$(${command} 2>&1)
  status_code=$?

  echo "$output"
  if [ ${status_code} -${operator} 0 ]; then
    echo ${error_message}
    exit 1
  fi

  echo ${output} | grep "$expected_message"
  if [ $? -ne 0 ]; then
    echo "'bazel build ${test_target}' should have logged \"${expected_message}\"."
        exit 1
  fi
  if [ "${additional_expected_message}" != "" ]; then
    echo ${output} | grep "$additional_expected_message"
    if [ $? -ne 0 ]; then
      echo "'bazel build ${test_target}' should have logged \"${additional_expected_message}\"."
          exit 1
    fi
  fi

  set -e
}

test_scala_library_expect_failure_on_missing_direct_deps_strict_is_disabled_by_default() {
  expected_message="not found: value C"
  test_target='test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_user'

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "$expected_message" $test_target ""
}

test_scala_library_expect_failure_on_missing_direct_deps() {
  dependenecy_target=$1
  test_target=$2

  local expected_message="buildozer 'add deps $dependenecy_target' //$test_target"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" $test_target "--strict_java_deps=error"
}

test_scala_library_expect_failure_on_missing_direct_internal_deps() {
  dependenecy_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_user'

  test_scala_library_expect_failure_on_missing_direct_deps $dependenecy_target $test_target
}

test_scala_binary_expect_failure_on_missing_direct_deps() {
  dependency_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='test_expect_failure/missing_direct_deps/internal_deps:user_binary'

  test_scala_library_expect_failure_on_missing_direct_deps ${dependency_target} ${test_target}
}

test_scala_binary_expect_failure_on_missing_direct_deps_located_in_dependency_which_is_scala_binary() {
  dependency_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='test_expect_failure/missing_direct_deps/internal_deps:binary_user_of_binary'

  test_scala_library_expect_failure_on_missing_direct_deps ${dependency_target} ${test_target}
}

test_scala_library_expect_failure_on_missing_direct_external_deps_jar() {
  dependenecy_target='@com_google_guava_guava_21_0//:com_google_guava_guava_21_0'
  test_target='test_expect_failure/missing_direct_deps/external_deps:transitive_external_dependency_user'

  test_scala_library_expect_failure_on_missing_direct_deps $dependenecy_target $test_target
}

test_scala_library_expect_failure_on_missing_direct_external_deps_file_group() {
  dependenecy_target='@com_google_guava_guava_21_0_with_file//jar:jar'
  test_target='test_expect_failure/missing_direct_deps/external_deps:transitive_external_dependency_user_file_group'

  test_scala_library_expect_failure_on_missing_direct_deps $dependenecy_target $test_target
}

test_scala_library_expect_failure_on_missing_direct_deps_warn_mode() {
  dependenecy_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_user'

  expected_message="warning: Target '$dependenecy_target' is used but isn't explicitly declared, please add it to the deps"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" ${test_target} "--strict_java_deps=warn" "ne"
}

test_scala_library_expect_failure_on_missing_direct_java() {
  dependency_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_java_user'

  expected_message="$dependency_target.*$test_target"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" $test_target "--strict_java_deps=error"
}

test_scala_library_expect_failure_on_java_in_src_jar_when_disabled() {
  test_target='//test_expect_failure/java_in_src_jar_when_disabled:java_source_jar'

  expected_message=".*Found java files in source jars but expect Java output is set to false"

  test_expect_failure_with_message "${expected_message}" $test_target
}

test_scala_library_expect_better_failure_message_on_missing_transitive_dependency_labels_from_other_jvm_rules() {
  transitive_target='.*transitive_dependency-ijar.jar'
  direct_target='//test_expect_failure/missing_direct_deps/internal_deps:direct_java_provider_dependency'
  test_target='//test_expect_failure/missing_direct_deps/internal_deps:dependent_on_some_java_provider'

  expected_message="Unknown label of file $transitive_target which came from $direct_target"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" $test_target "--strict_java_deps=error"
}

test_scala_library_expect_failure_on_missing_direct_deps_warn_mode_java() {
  dependency_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency'
  test_target='//test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_java_user'

  local expected_message="$dependency_target.*$test_target"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" ${test_target} "--strict_java_deps=warn" "ne"
}

test_scala_library_expect_failure_on_missing_direct_deps_off_mode() {
  expected_message="test_expect_failure/missing_direct_deps/internal_deps/A.scala:[0-9+]: error: not found: value C"
  test_target='test_expect_failure/missing_direct_deps/internal_deps:transitive_dependency_user'

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message}" ${test_target} "--strict_java_deps=off"
}

test_scala_junit_test_can_fail() {
  action_should_fail test test_expect_failure/scala_junit_test:failing_test
}

test_repl() {
  echo "import scalarules.test._; HelloLib.printMessage(\"foo\")" | bazel-bin/test/HelloLibRepl | grep "foo java" &&
  echo "import scalarules.test._; TestUtil.foo" | bazel-bin/test/HelloLibTestRepl | grep "bar" &&
  echo "import scalarules.test._; ScalaLibBinary.main(Array())" | bazel-bin/test/ScalaLibBinaryRepl | grep "A hui hou" &&
  echo "import scalarules.test._; ResourcesStripScalaBinary.main(Array())" | bazel-bin/test/ResourcesStripScalaBinaryRepl | grep "More Hello"
  echo "import scalarules.test._; A.main(Array())" | bazel-bin/test/ReplWithSources | grep "4 8 15"
}

test_benchmark_jmh() {
  RES=$(bazel run -- test/jmh:test_benchmark -i1 -f1 -wi 1)
  RESPONSE_CODE=$?
  if [[ $RES != *Result*Benchmark* ]]; then
    echo "Benchmark did not produce expected output:\n$RES"
    exit 1
  fi
  exit $RESPONSE_CODE
}

test_multi_service_manifest() {
  deploy_jar='ScalaBinary_with_service_manifest_srcs_deploy.jar'
  meta_file='META-INF/services/org.apache.beam.sdk.io.FileSystemRegistrar'
  bazel build test:$deploy_jar
  unzip -p bazel-bin/test/$deploy_jar $meta_file > service_manifest.txt
  diff service_manifest.txt test/example_jars/expected_service_manifest.txt
  RESPONSE_CODE=$?
  rm service_manifest.txt
  exit $RESPONSE_CODE
}



action_should_fail() {
  # runs the tests locally
  set +e
  TEST_ARG=$@
  DUMMY=$(bazel $TEST_ARG)
  RESPONSE_CODE=$?
  if [ $RESPONSE_CODE -eq 0 ]; then
    echo -e "${RED} \"bazel $TEST_ARG\" should have failed but passed. $NC"
    exit -1
  else
    exit 0
  fi
}

action_should_fail_with_message() {
  set +e
  MSG=$1
  TEST_ARG=${@:2}
  RES=$(bazel $TEST_ARG 2>&1)
  RESPONSE_CODE=$?
  echo $RES | grep -- "$MSG"
  GREP_RES=$?
  if [ $RESPONSE_CODE -eq 0 ]; then
    echo -e "${RED} \"bazel $TEST_ARG\" should have failed but passed. $NC"
    exit 1
  elif [ $GREP_RES -ne 0 ]; then
    echo -e "${RED} \"bazel $TEST_ARG\" should have failed with message \"$MSG\" but did not. $NC"
  else
    exit 0
  fi
}

xmllint_test() {
  find -L ./bazel-testlogs -iname "*.xml" | xargs -n1 xmllint > /dev/null
}

multiple_junit_suffixes() {
  bazel test //test:JunitMultipleSuffixes

  matches=$(grep -c -e 'Discovered classes' -e 'scalarules.test.junit.JunitSuffixIT' -e 'scalarules.test.junit.JunitSuffixE2E' ./bazel-testlogs/test/JunitMultipleSuffixes/test.log)
  if [ $matches -eq 3 ]; then
    return 0
  else
    return 1
  fi
}

multiple_junit_prefixes() {
  bazel test //test:JunitMultiplePrefixes

  matches=$(grep -c -e 'Discovered classes' -e 'scalarules.test.junit.TestJunitCustomPrefix' -e 'scalarules.test.junit.OtherCustomPrefixJunit' ./bazel-testlogs/test/JunitMultiplePrefixes/test.log)
  if [ $matches -eq 3 ]; then
    return 0
  else
    return 1
  fi
}

multiple_junit_patterns() {
  bazel test //test:JunitPrefixesAndSuffixes
  matches=$(grep -c -e 'Discovered classes' -e 'scalarules.test.junit.TestJunitCustomPrefix' -e 'scalarules.test.junit.JunitSuffixE2E' ./bazel-testlogs/test/JunitPrefixesAndSuffixes/test.log)
  if [ $matches -eq 3 ]; then
    return 0
  else
    return 1
  fi
}

junit_generates_xml_logs() {
  bazel test //test:JunitTestWithDeps
  matches=$(grep -c -e "testcase name='hasCompileTimeDependencies'" -e "testcase name='hasRuntimeDependencies'" ./bazel-testlogs/test/JunitTestWithDeps/test.xml)
  if [ $matches -eq 2 ]; then
    return 0
  else
    return 1
  fi
  test -e
}

test_junit_test_must_have_prefix_or_suffix() {
  action_should_fail test test_expect_failure/scala_junit_test:no_prefix_or_suffix
}

test_junit_test_errors_when_no_tests_found() {
  action_should_fail test test_expect_failure/scala_junit_test:no_tests_found
}

test_resources() {
  RESOURCE_NAME="resource.txt"
  TARGET=$1
  OUTPUT_JAR="bazel-bin/test/src/main/scala/scalarules/test/resources/$TARGET.jar"
  FULL_TARGET="test/src/main/scala/scalarules/test/resources/$TARGET.jar"
  bazel build $FULL_TARGET
  jar tf $OUTPUT_JAR | grep $RESOURCE_NAME
}

scala_library_jar_without_srcs_must_include_direct_file_resources(){
  test_resources "noSrcsWithDirectFileResources"
}

scala_library_jar_without_srcs_must_include_filegroup_resources(){
  test_resources "noSrcsWithFilegroupResources"
}

scala_library_jar_without_srcs_must_fail_on_mismatching_resource_strip_prefix() {
  action_should_fail build test_expect_failure/wrong_resource_strip_prefix:noSrcsJarWithWrongStripPrefix
}

scala_test_test_filters() {
    # test package wildcard (both)
    local output=$(bazel test \
                         --cache_test_results=no \
                         --test_output streamed \
                         --test_filter scalarules.test.* \
                         test:TestFilterTests)
    if [[ $output != *"tests a"* || $output != *"tests b"* ]]; then
        echo "Should have contained test output from both test filter test a and b"
        exit 1
    fi
    # test just one
    local output=$(bazel test \
                         --cache_test_results=no \
                         --test_output streamed \
                         --test_filter scalarules.test.TestFilterTestA \
                         test:TestFilterTests)
    if [[ $output != *"tests a"* || $output == *"tests b"* ]]; then
        echo "Should have only contained test output from test filter test a"
        exit 1
    fi
}

scala_junit_test_test_filter(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.FirstFilterTest#(method1|method2)$|scalarules.test.junit.SecondFilterTest#(method2|method3)$' \
    test:JunitFilterTest)
  local expected=(
      "scalarules.test.junit.FirstFilterTest#method1"
      "scalarules.test.junit.FirstFilterTest#method2"
      "scalarules.test.junit.SecondFilterTest#method2"
      "scalarules.test.junit.SecondFilterTest#method3")
  local unexpected=(
      "scalarules.test.junit.FirstFilterTest#method3"
      "scalarules.test.junit.SecondFilterTest#method1"
      "scalarules.test.junit.ThirdFilterTest#method1"
      "scalarules.test.junit.ThirdFilterTest#method2"
      "scalarules.test.junit.ThirdFilterTest#method3")
  for method in "${expected[@]}"; do
    if ! grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Expected $method in output, but was not found."
      exit 1
    fi
  done
  for method in "${unexpected[@]}"; do
    if grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Not expecting $method in output, but was found."
      exit 1
    fi
  done
}

scala_junit_test_test_filter_custom_runner(){
  bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.JunitCustomRunnerTest#' \
    test:JunitCustomRunner
}

scala_specs2_junit_test_test_filter_everything(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=.*' \
    test:Specs2Tests)
  local expected=(
    "[info] JunitSpec2RegexTest"
    "[info] JunitSpecs2AnotherTest"
    "[info] JunitSpecs2Test")
  local unexpected=(
      "[info] UnrelatedTest")
  for method in "${expected[@]}"; do
    if ! grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Expected $method in output, but was not found."
      exit 1
    fi
  done
  for method in "${unexpected[@]}"; do
    if grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Not expecting $method in output, but was found."
      exit 1
    fi
  done
}

scala_specs2_junit_test_test_filter_whole_spec(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpecs2Test#' \
    test:Specs2Tests)
  local expected=(
      "+ run smoothly in bazel"
      "+ not run smoothly in bazel")
  local unexpected=(
      "+ run from another test")
  for method in "${expected[@]}"; do
    if ! grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Expected $method in output, but was not found."
      exit 1
    fi
  done
  for method in "${unexpected[@]}"; do
    if grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Not expecting $method in output, but was found."
      exit 1
    fi
  done
}

scala_specs2_junit_test_test_filter_one_test(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpecs2Test#specs2 tests should::run smoothly in bazel$' \
    test:Specs2Tests)
  local expected="+ run smoothly in bazel"
  local unexpected="+ not run smoothly in bazel"
  if ! grep "$expected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Expected $expected in output, but was not found."
    exit 1
  fi
  if grep "$unexpected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Not expecting $unexpected in output, but was found."
    exit 1
  fi
}

scala_specs2_only_filtered_test_shows_in_the_xml(){
  bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpecs2Test#specs2 tests should::run smoothly in bazel$' \
    test:Specs2Tests
  matches=$(grep -c -e "testcase name='specs2 tests should::run smoothly in bazel'" -e "testcase name='specs2 tests should::not run smoothly in bazel'" ./bazel-testlogs/test/Specs2Tests/test.xml)
  if [ $matches -eq 1 ]; then
    return 0
  else
    echo "Expecting only one result, found more than one. Please check 'bazel-testlogs/test/Specs2Tests/test.xml'"
    return 1
  fi
  test -e
}

scala_specs2_junit_test_test_filter_exact_match(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpecs2AnotherTest#other specs2 tests should::run from another test$' \
    test:Specs2Tests)
  local expected="+ run from another test"
  local unexpected="+ run from another test 2"
  if ! grep "$expected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Expected $expected in output, but was not found."
    exit 1
  fi
  if grep "$unexpected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Not expecting $unexpected in output, but was found."
    exit 1
  fi
}

scala_specs2_junit_test_test_filter_exact_match_unsafe_characters(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpec2RegexTest#\Qtests with unsafe characters should::2 + 2 != 5\E$' \
    test:Specs2Tests)
  local expected="+ 2 + 2 != 5"
  local unexpected="+ work escaped (with regex)"
  if ! grep "$expected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Expected $expected in output, but was not found."
    exit 1
  fi
  if grep "$unexpected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Not expecting $unexpected in output, but was found."
    exit 1
  fi
}

scala_specs2_junit_test_test_filter_exact_match_escaped_and_sanitized(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpec2RegexTest#\Qtests with unsafe characters should::work escaped [with regex]\E$' \
    test:Specs2Tests)
  local expected="+ work escaped (with regex)"
  local unexpected="+ 2 + 2 != 5"
  if ! grep "$expected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Expected $expected in output, but was not found."
    exit 1
  fi
  if grep "$unexpected" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Not expecting $unexpected in output, but was found."
    exit 1
  fi
}

scala_specs2_junit_test_test_filter_match_multiple_methods(){
  local output=$(bazel test \
    --nocache_test_results \
    --test_output=streamed \
    '--test_filter=scalarules.test.junit.specs2.JunitSpecs2AnotherTest#other specs2 tests should::(\Qrun from another test\E|\Qrun from another test 2\E)$' \
    test:Specs2Tests)
  local expected=(
      "+ run from another test"
      "+ run from another test 2")
  local unexpected=(
      "+ not run")
  for method in "${expected[@]}"; do
    if ! grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Expected $method in output, but was not found."
      exit 1
    fi
  done
  for method in "${unexpected[@]}"; do
    if grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Not expecting $method in output, but was found."
      exit 1
    fi
  done
}


scala_specs2_exception_in_initializer_without_filter(){
  expected_message="org.specs2.control.UserException: cannot create an instance for class scalarules.test.junit.specs2.FailingTest"
  test_command="test_expect_failure/scala_junit_test:specs2_failing_test"

  test_expect_failure_with_message "$expected_message" $test_filter $test_command
}

scala_specs2_exception_in_initializer_terminates_without_timeout(){
  local output=$(bazel test \
    --test_output=streamed \
    --test_timeout=10 \
    '--test_filter=scalarules.test.junit.specs2.FailingTest#' \
    test_expect_failure/scala_junit_test:specs2_failing_test)
  local expected=(
      "org.specs2.control.UserException: cannot create an instance for class scalarules.test.junit.specs2.FailingTest")
  local unexpected=(
      "TIMEOUT")
  for method in "${expected[@]}"; do
    if ! grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Expected $method in output, but was not found."
      exit 1
    fi
  done
  for method in "${unexpected[@]}"; do
    if grep "$method" <<<$output; then
      echo "output:"
      echo "$output"
      echo "Not expecting $method in output, but was found."
      exit 1
    fi
  done
}

scalac_jvm_flags_are_configured(){
  action_should_fail build //test_expect_failure/compilers_jvm_flags:can_configure_jvm_flags_for_scalac
}

javac_jvm_flags_are_configured(){
  action_should_fail build //test_expect_failure/compilers_jvm_flags:can_configure_jvm_flags_for_javac
}

javac_jvm_flags_via_javacopts_are_configured(){
  action_should_fail build //test_expect_failure/compilers_jvm_flags:can_configure_jvm_flags_for_javac_via_javacopts
}

scalac_jvm_flags_are_expanded(){
  action_should_fail_with_message \
    "--jvm_flag=test_expect_failure/compilers_jvm_flags/args.txt" \
    build --verbose_failures //test_expect_failure/compilers_jvm_flags:can_expand_jvm_flags_for_scalac
}

javac_jvm_flags_are_expanded(){
  action_should_fail_with_message \
    "invalid flag: test_expect_failure/compilers_jvm_flags/args.txt" \
    build --verbose_failures //test_expect_failure/compilers_jvm_flags:can_expand_jvm_flags_for_javac
}

javac_jvm_flags_via_javacopts_are_expanded(){
  action_should_fail_with_message \
    "invalid flag: test_expect_failure/compilers_jvm_flags/args.txt" \
    build --verbose_failures //test_expect_failure/compilers_jvm_flags:can_expand_jvm_flags_for_javac_via_javacopts
}

java_toolchain_javacopts_are_used(){
  action_should_fail_with_message \
    "invalid flag: -InvalidFlag" \
    build --java_toolchain=//test_expect_failure/compilers_javac_opts:a_java_toolchain \
      --verbose_failures //test_expect_failure/compilers_javac_opts:can_configure_jvm_flags_for_javac_via_javacopts
}

revert_internal_change() {
  sed -i.bak "s/println(\"altered\")/println(\"orig\")/" $no_recompilation_path/C.scala
  rm $no_recompilation_path/C.scala.bak
}

test_scala_library_expect_no_recompilation_on_internal_change_of_transitive_dependency() {
  set +e
  no_recompilation_path="test/src/main/scala/scalarules/test/strict_deps/no_recompilation"
  build_command="bazel build //$no_recompilation_path/... --subcommands --strict_java_deps=error"

  echo "running initial build"
  $build_command
  echo "changing internal behaviour of C.scala"
  sed -i.bak "s/println(\"orig\")/println(\"altered\")/" ./$no_recompilation_path/C.scala

  echo "running second build"
  output=$(${build_command} 2>&1)

  not_expected_recompiled_target="//$no_recompilation_path:transitive_dependency_user"

  echo ${output} | grep "$not_expected_recompiled_target"
  if [ $? -eq 0 ]; then
    echo "bazel build was executed after change of internal behaviour of 'transitive_dependency' target. compilation of 'transitive_dependency_user' should not have been triggered."
    revert_internal_change
    exit 1
  fi

  revert_internal_change
  set -e
}

test_scala_library_expect_no_recompilation_on_internal_change_of_java_dependency() {
  test_scala_library_expect_no_recompilation_of_target_on_internal_change_of_dependency "C.java" "s/System.out.println(\"orig\")/System.out.println(\"altered\")/"
}

test_scala_library_expect_no_recompilation_on_internal_change_of_scala_dependency() {
  test_scala_library_expect_no_recompilation_of_target_on_internal_change_of_dependency "B.scala" "s/println(\"orig\")/println(\"altered\")/"
}

test_scala_library_expect_no_recompilation_of_target_on_internal_change_of_dependency() {
  test_scala_library_expect_no_recompilation_on_internal_change $1 $2 ":user" "'user'"
}

test_scala_library_expect_no_java_recompilation_on_internal_change_of_scala_sibling() {
  test_scala_library_expect_no_recompilation_on_internal_change "B.scala" "s/println(\"orig_sibling\")/println(\"altered_sibling\")/" "/dependency_java" "java sibling"
}

test_scala_library_expect_no_recompilation_on_internal_change() {
  changed_file=$1
  changed_content=$2
  dependency=$3
  dependency_description=$4
  set +e
  no_recompilation_path="test/src/main/scala/scalarules/test/ijar"
  build_command="bazel build //$no_recompilation_path/... --subcommands"

  echo "running initial build"
  $build_command
  echo "changing internal behaviour of $changed_file"
  sed -i.bak $changed_content ./$no_recompilation_path/$changed_file

  echo "running second build"
  output=$(${build_command} 2>&1)

  not_expected_recompiled_action="$no_recompilation_path$dependency"

  echo ${output} | grep "$not_expected_recompiled_action"
  if [ $? -eq 0 ]; then
    echo "bazel build was executed after change of internal behaviour of 'dependency' target. compilation of $dependency_description should not have been triggered."
    revert_change $no_recompilation_path $changed_file
    exit 1
  fi

  revert_change $no_recompilation_path $changed_file
  set -e
}

revert_change() {
  mv $1/$2.bak $1/$2
}

test_scala_import_expect_failure_on_missing_direct_deps_warn_mode() {
  dependency_target1='//test_expect_failure/scala_import:cats'
  dependency_target2='//test_expect_failure/scala_import:guava'
  test_target='test_expect_failure/scala_import:scala_import_propagates_compile_deps'

  local expected_message1="buildozer 'add deps $dependency_target1' //$test_target"
  local expected_message2="buildozer 'add deps $dependency_target2' //$test_target"

  test_expect_failure_or_warning_on_missing_direct_deps_with_expected_message "${expected_message1}" ${test_target} "--strict_java_deps=warn" "ne" "${expected_message2}"
}

test_scalaopts_from_scala_toolchain() {
  action_should_fail build --extra_toolchains="//test_expect_failure/scalacopts_from_toolchain:failing_scala_toolchain" //test_expect_failure/scalacopts_from_toolchain:failing_build
}

test_unused_dependency_checker_mode_set_in_rule() {
  action_should_fail build //test_expect_failure/unused_dependency_checker:failing_build
}

test_unused_dependency_checker_mode_from_scala_toolchain() {
  action_should_fail build --extra_toolchains="//test_expect_failure/unused_dependency_checker:failing_scala_toolchain" //test_expect_failure/unused_dependency_checker:toolchain_failing_build
}

test_unused_dependency_checker_mode_override_toolchain() {
  bazel build --extra_toolchains="//test_expect_failure/unused_dependency_checker:failing_scala_toolchain" //test_expect_failure/unused_dependency_checker:toolchain_override
}

test_unused_dependency_checker_mode_warn() {
  # this is a hack to invalidate the cache, so that the target actually gets built and outputs warnings.
  bazel build \
    --strict_java_deps=warn \
    //test:UnusedDependencyCheckerWarn

  local output
  output=$(bazel build \
    --strict_java_deps=off \
    //test:UnusedDependencyCheckerWarn 2>&1
  )

  if [ $? -ne 0 ]; then
    echo "Target with unused dependency failed to build with status $?"
    echo "$output"
    exit 1
  fi

  local expected="warning: Target '//test:UnusedLib' is specified as a dependency to //test:UnusedDependencyCheckerWarn but isn't used, please remove it from the deps."

  echo "$output" | grep "$expected"
  if [ $? -ne 0 ]; then
    echo "Expected output:[$output] to contain [$expected]"
    exit 1
  fi
}

test_scala_import_library_passes_labels_of_direct_deps() {
  dependency_target='//test_expect_failure/scala_import:root_for_scala_import_passes_labels_of_direct_deps'
  test_target='test_expect_failure/scala_import:leaf_for_scala_import_passes_labels_of_direct_deps'

  test_scala_library_expect_failure_on_missing_direct_deps $dependency_target $test_target
}

test_scala_classpath_resources_expect_warning_on_namespace_conflict() {
  local output=$(bazel build \
    --verbose_failures \
    //test/src/main/scala/scalarules/test/classpath_resources:classpath_resource_duplicates
  )

  local expected="Classpath resource file classpath-resourcehas a namespace conflict with another file: classpath-resource"

  if ! grep "$method" <<<$output; then
    echo "output:"
    echo "$output"
    echo "Expected $method in output, but was not found."
    exit 1
  fi
}

scala_binary_common_jar_is_exposed_in_build_event_protocol() {
  local target=$1
  set +e
  bazel build test:$target --build_event_text_file=$target_bes.txt
  cat $target_bes.txt | grep "test/$target.jar"
  if [ $? -ne 0 ]; then
    echo "test/$target.jar was not found in build event protocol:"
    cat $target_bes.txt
    rm $target_bes.txt
    exit 1
  fi

  rm $target_bes.txt
  set -e
}

scala_binary_jar_is_exposed_in_build_event_protocol() {
  scala_binary_common_jar_is_exposed_in_build_event_protocol ScalaLibBinary
}

scala_test_jar_is_exposed_in_build_event_protocol() {
  scala_binary_common_jar_is_exposed_in_build_event_protocol HelloLibTest
}

scala_junit_test_jar_is_exposed_in_build_event_protocol() {
  scala_binary_common_jar_is_exposed_in_build_event_protocol JunitTestWithDeps
}

test_scala_import_source_jar_should_be_fetched_when_fetch_sources_is_set_to_true() {
  test_scala_import_fetch_sources
}

test_scala_import_source_jar_should_be_fetched_when_env_bazel_jvm_fetch_sources_is_set_to_true() {
  test_scala_import_fetch_sources_with_env_bazel_jvm_fetch_sources_set_to "TruE" # as implied, the value is case insensitive
}

test_scala_import_source_jar_should_not_be_fetched_when_env_bazel_jvm_fetch_sources_is_set_to_non_true() {
  test_scala_import_fetch_sources_with_env_bazel_jvm_fetch_sources_set_to "false" "and expect no source jars"
}

test_scala_import_fetch_sources_with_env_bazel_jvm_fetch_sources_set_to() {
  # the existence of the env var should cause the import repository rule to re-fetch the dependency
  # and therefore the order of tests is not expected to matter
  export BAZEL_JVM_FETCH_SOURCES=$1
  local expect_failure=$2

  if [[ ${expect_failure} ]]; then
    action_should_fail test_scala_import_fetch_sources
  else
    test_scala_import_fetch_sources
  fi

  unset BAZEL_JVM_FETCH_SOURCES
}

test_scala_import_fetch_sources() {
  local srcjar_name="guava-21.0-src.jar"
  local bazel_out_external_guava_21=$(bazel info output_base)/external/com_google_guava_guava_21_0

  set -e
  bazel build //test/src/main/scala/scalarules/test/fetch_sources/...
  set +e

  assert_file_exists $bazel_out_external_guava_21/$srcjar_name
}

test_compilation_succeeds_with_plus_one_deps_on() {
  bazel build --extra_toolchains=//test_expect_failure/plus_one_deps:plus_one_deps //test_expect_failure/plus_one_deps/internal_deps:a
}
test_compilation_fails_with_plus_one_deps_undefined() {
  action_should_fail build //test_expect_failure/plus_one_deps/internal_deps:a
}
test_compilation_succeeds_with_plus_one_deps_on_for_external_deps() {
  bazel build --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps" //test_expect_failure/plus_one_deps/external_deps:a
}
test_compilation_succeeds_with_plus_one_deps_on_also_for_exports_of_deps() {
  bazel build --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps" //test_expect_failure/plus_one_deps/exports_of_deps/...
}
test_compilation_succeeds_with_plus_one_deps_on_also_for_deps_of_exports() {
  bazel build --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps" //test_expect_failure/plus_one_deps/deps_of_exports/...
}
test_plus_one_deps_only_works_for_java_info_targets() {
  #for example doesn't break scala proto which depends on proto_library
  bazel build --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps" //test/proto:test_proto
}
test_unused_dependency_fails_even_if_also_exists_in_plus_one_deps() {
  action_should_fail build --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps_with_unused_error" //test_expect_failure/plus_one_deps/with_unused_deps:a
}

test_coverage_on() {
    bazel coverage \
          --extra_toolchains="//test/coverage:enable_code_coverage_aspect" \
          //test/coverage/...
    diff test/coverage/expected-coverage.dat $(bazel info bazel-testlogs)/test/coverage/test-all/coverage.dat
}

assert_file_exists() {
  if [[ -f $1 ]]; then
    echo "File $1 exists."
    exit 0
  else
    echo "File $1 does not exist."
    exit 1
  fi
}

dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# shellcheck source=./test_runner.sh
. "${dir}"/test_runner.sh
runner=$(get_test_runner "${1:-local}")

$runner bazel build test/...
#$runner bazel build "test/... --all_incompatible_changes"
$runner bazel test test/...
$runner bazel test third_party/...
# UnusedDependencyChecker doesn't work with strict_java_deps
$runner bazel build "--strict_java_deps=ERROR -- test/... -test:UnusedDependencyChecker"
#$runner bazel build "--strict_java_deps=ERROR --all_incompatible_changes -- test/... -test:UnusedDependencyChecker"
$runner bazel test "--strict_java_deps=ERROR -- test/... -test:UnusedDependencyChecker"
$runner test_disappearing_class
$runner find -L ./bazel-testlogs -iname "*.xml"
$runner xmllint_test
$runner test_transitive_deps
$runner test_scala_library_suite
$runner test_repl
$runner test_benchmark_jmh
$runner multiple_junit_suffixes
$runner multiple_junit_prefixes
$runner test_scala_junit_test_can_fail
$runner junit_generates_xml_logs
$runner scala_library_jar_without_srcs_must_fail_on_mismatching_resource_strip_prefix
$runner multiple_junit_patterns
$runner test_junit_test_must_have_prefix_or_suffix
$runner test_junit_test_errors_when_no_tests_found
$runner scala_library_jar_without_srcs_must_include_direct_file_resources
$runner scala_library_jar_without_srcs_must_include_filegroup_resources
$runner scala_test_test_filters
$runner scala_junit_test_test_filter
$runner scala_junit_test_test_filter_custom_runner
$runner scala_specs2_junit_test_test_filter_everything
$runner scala_specs2_junit_test_test_filter_one_test
$runner scala_specs2_junit_test_test_filter_whole_spec
$runner scala_specs2_junit_test_test_filter_exact_match
$runner scala_specs2_junit_test_test_filter_exact_match_unsafe_characters
$runner scala_specs2_junit_test_test_filter_exact_match_escaped_and_sanitized
$runner scala_specs2_junit_test_test_filter_match_multiple_methods
$runner scala_specs2_exception_in_initializer_without_filter
$runner scala_specs2_exception_in_initializer_terminates_without_timeout
$runner scala_specs2_only_filtered_test_shows_in_the_xml
$runner scalac_jvm_flags_are_configured
$runner javac_jvm_flags_are_configured
$runner javac_jvm_flags_via_javacopts_are_configured
$runner scalac_jvm_flags_are_expanded
$runner javac_jvm_flags_are_expanded
$runner javac_jvm_flags_via_javacopts_are_expanded
$runner test_scala_library_expect_failure_on_missing_direct_internal_deps
$runner test_scala_library_expect_failure_on_missing_direct_external_deps_jar
$runner test_scala_library_expect_failure_on_missing_direct_external_deps_file_group
$runner test_scala_library_expect_failure_on_missing_direct_deps_strict_is_disabled_by_default
$runner test_scala_binary_expect_failure_on_missing_direct_deps
$runner test_scala_binary_expect_failure_on_missing_direct_deps_located_in_dependency_which_is_scala_binary
$runner test_scala_library_expect_failure_on_missing_direct_deps_warn_mode
$runner test_scala_library_expect_failure_on_missing_direct_deps_off_mode
$runner test_unused_dependency_checker_mode_from_scala_toolchain
$runner test_unused_dependency_checker_mode_set_in_rule
$runner test_unused_dependency_checker_mode_override_toolchain
$runner test_scala_library_expect_no_recompilation_on_internal_change_of_transitive_dependency
$runner test_multi_service_manifest
$runner test_scala_library_expect_no_recompilation_on_internal_change_of_scala_dependency
$runner test_scala_library_expect_no_recompilation_on_internal_change_of_java_dependency
$runner test_scala_library_expect_no_java_recompilation_on_internal_change_of_scala_sibling
$runner test_scala_library_expect_failure_on_missing_direct_java
$runner test_scala_library_expect_failure_on_java_in_src_jar_when_disabled
$runner test_scala_library_expect_failure_on_missing_direct_deps_warn_mode_java
$runner test_scala_library_expect_better_failure_message_on_missing_transitive_dependency_labels_from_other_jvm_rules
$runner test_scala_import_expect_failure_on_missing_direct_deps_warn_mode
$runner bazel build "test_expect_failure/missing_direct_deps/internal_deps/... --strict_java_deps=warn"
$runner test_scalaopts_from_scala_toolchain
$runner test_scala_import_library_passes_labels_of_direct_deps
$runner java_toolchain_javacopts_are_used
$runner test_scala_classpath_resources_expect_warning_on_namespace_conflict
$runner bazel build //test_expect_failure/proto_source_root/... --strict_proto_deps=off
$runner scala_binary_jar_is_exposed_in_build_event_protocol
$runner scala_test_jar_is_exposed_in_build_event_protocol
$runner scala_junit_test_jar_is_exposed_in_build_event_protocol
$runner test_scala_import_source_jar_should_be_fetched_when_fetch_sources_is_set_to_true
$runner test_scala_import_source_jar_should_be_fetched_when_env_bazel_jvm_fetch_sources_is_set_to_true
$runner test_scala_import_source_jar_should_not_be_fetched_when_env_bazel_jvm_fetch_sources_is_set_to_non_true
$runner test_unused_dependency_checker_mode_warn
$runner test_override_javabin
$runner test_compilation_succeeds_with_plus_one_deps_on
$runner test_compilation_fails_with_plus_one_deps_undefined
$runner test_compilation_succeeds_with_plus_one_deps_on_for_external_deps
$runner test_compilation_succeeds_with_plus_one_deps_on_also_for_exports_of_deps
$runner test_compilation_succeeds_with_plus_one_deps_on_also_for_deps_of_exports
$runner test_plus_one_deps_only_works_for_java_info_targets
$runner bazel test //test/... --extra_toolchains="//test_expect_failure/plus_one_deps:plus_one_deps"
$runner test_unused_dependency_fails_even_if_also_exists_in_plus_one_deps
$runner test_coverage_on
