#! /usr/bin/env bash
scriptPath=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

testFailed=false

testExitCode() {
  expectedExitCode="$2"
  actualExitCode="$3"
  test="When vulnerabilities are present and ${1} then exit code is ${expectedExitCode}"

  printf "\n"

  if [ "${actualExitCode}" -eq "${expectedExitCode}" ]; then
    printf "✔"
  else
    printf "Expected error code: ${expectedExitCode} - Recieved error code: ${actualExitCode}\n"
    printf "✗"

    testFailed=true
  fi

  printf " ${test}\n\n"

  rm -f .iyarc
}

callIya() {
  "${scriptPath}/../bin/improved-yarn-audit" -r "$@"
}

runTests() {
  cd "${scriptPath}"

  rm -f package.json
  rm -f yarn.lock
  rm -f .iyarc

  cp vunerable-package.json package.json
  cp vunerable-yarn.lock yarn.lock

  # test 1
  callIya
  testExitCode "not excluded" "9" "$?"

  # test 2
  excludedAdvisories=$(<mocks/test-2.args)
  callIya -e "${excludedAdvisories}"
  testExitCode "vulnerabilities are present and they are excluded on the command line" "0" "$?"

  # test 3
  touch .iyarc
  cp mocks/test-3.iyarc .iyarc
  callIya
  testExitCode "vulnerabilities are present and they are excluded in .iyarc" "0" "$?"
  rm .iyarc

  # test 4
  touch .iyarc
  cp mocks/test-4.iyarc .iyarc
  callIya
  testExitCode "they are excluded in .iyarc file with comments" "0" "$?"

  # test 5
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-5.iyarc .iyarc
  callIya -e 1469,1594,GHSA-3fw8-66wf-pr7m,GHSA-42xw-2xvc-qx8m
  testExitCode "vulnerabilities are present and they are excluded in .iyarc but exclusions are in the command line" "7" "$?"

  # test 6
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-6.iyarc .iyarc
  callIya -i
  testExitCode "dev dependencies flag is present then dev vulnerabilities are ignored" "6" "$?"

  # test 7
  callIya -s moderate
  testExitCode "min severity is moderate" "8" "$?"

  # test 8
  callIya -s high
  testExitCode "min severity is high" "6" "$?"

  # test 9
  # Moderate values = GHSA-gpvr-g6gh-9mc2,GHSA-wrvr-8mpx-r7pp
  # High Severity values = GHSA-jjv7-qpx3-h62q,GHSA-f9cm-p3w6-xvr3,GHSA-gqgv-6jq5-jjj9,GHSA-42xw-2xvc-qx8m,GHSA-4w2v-q235-vp99,GHSA-cph5-m8f7-6c5x
  callIya -s moderate -e GHSA-gpvr-g6gh-9mc2,GHSA-wrvr-8mpx-r7pp,GHSA-jjv7-qpx3-h62q,GHSA-f9cm-p3w6-xvr3,GHSA-gqgv-6jq5-jjj9,GHSA-42xw-2xvc-qx8m,GHSA-4w2v-q235-vp99,GHSA-cph5-m8f7-6c5x
  testExitCode "they are excluded on the command line and min severity is moderate" "0" "$?"

  # test 10
  # High Severity values = GHSA-jjv7-qpx3-h62q,GHSA-f9cm-p3w6-xvr3,GHSA-gqgv-6jq5-jjj9,GHSA-42xw-2xvc-qx8m,GHSA-4w2v-q235-vp99,GHSA-cph5-m8f7-6c5x
  callIya -s high -e GHSA-jjv7-qpx3-h62q,GHSA-f9cm-p3w6-xvr3,GHSA-gqgv-6jq5-jjj9,GHSA-42xw-2xvc-qx8m,GHSA-4w2v-q235-vp99,GHSA-cph5-m8f7-6c5x
  testExitCode "they are excluded on the command line and min severity is high" "0" "$?"

  # test 11
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-11.iyarc .iyarc
  callIya -s moderate
  testExitCode "they are excluded in .iyarc and min severity is moderate" "0" "$?"

  # test 12
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-12.iyarc .iyarc
  callIya -s high
  testExitCode "they are excluded in .iyarc and min severity is high" "0" "$?"

  # test 13
  rm -f package.json
  rm -f yarn.lock

  cp huge-package.json package.json
  cp huge-yarn.lock yarn.lock

  rm -f .iyarc
  touch .iyarc
  cp mocks/test-13.iyarc .iyarc
  callIya -s high
  testExitCode "the package JSON has a large number of dependencies" "0" "$?"

  rm -f package.json
  rm -f yarn.lock

  cp vunerable-package.json package.json
  cp vunerable-yarn.lock yarn.lock

  # test 14
  excludedAdvisories=$(<mocks/test-14.args)
  callIya -e "${excludedAdvisories},9999,1234"
  testExitCode "some of the exclusions passed via cli are missing" "0" "$?"

  # test 15
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-15.iyarc .iyarc
  callIya
  testExitCode "some of the exclusions passed via .iyarc are missing" "0" "$?"

  # test 16
  rm -f .iyarc
  excludedAdvisories=$(<mocks/test-16.args)
  callIya -e "${excludedAdvisories}" -f
  testExitCode "some of the exclusions passed via cli are missing and --fail-on-missing-exclusions is passed" "2" "$?"

  # test 17
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-17.iyarc .iyarc
  callIya -f
  testExitCode "some of the exclusions passed via .iyarc are missing and --fail-on-missing-exclusions is passed" "1" "$?"

  # test 18
  expectedVersion=$(echo $(grep '"version": ' ../package.json | cut -d '"' -f 4))

  outputVersion=$(callIya -v 2>&1)
  testExitCode "--version is passed" "1" "$?"

  if [ "${outputVersion}" != "${expectedVersion}" ]; then
    echo "TEST FAILURE: Incorrect version was output: ${outputVersion} - Expected: ${expectedVersion}"
    testFailed=true
  fi

  # test 19
  callIya -h
  testExitCode "--help is passed" "1" "$?"

  # test 20
  callIya -d
  testExitCode "--debug is passed" "9" "$?"

  # test 21
  rm -f .iyarc
  touch .iyarc
  cp mocks/test-21.iyarc .iyarc
  callIya
  testExitCode ".iyarc contains no exclusions" "9" "$?"
}

runTests

if [ "${testFailed}" == true ]; then
  echo "Test Result: FAILURE"
  echo "There were test failures"

  exit 1
else
  echo "Test Result: PASS"
fi
