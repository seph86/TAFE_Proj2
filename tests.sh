#!/bin/bash

# ============================================================
# This is a test script to verify api functions are functional
# ============================================================

# It was a mistake to make such a complex script in bash...
# I should of used python.

# file locations
token_file="/tmp/test_token.u4i8y44XfR"
output_file="$(mktemp)"

# set default options
host="127.0.0.1"
port="8080"
protocol="http://"
verbose=false
output=false
ratelimit=false
curl_data=""
token=""
pass2="StrongPassword99"

# If token file exists load it
if [ -f $token_file ]; then
  token=$(cat $token_file)
fi

if [ -f ".settings" ]; then
  user=$(grep "^test_user" .settings | awk 'BEGIN {RS="\n"}{split($0,a,"="); print a[2]}' | sed 's/\r//g')
  if [ $? -ne 0 ]; then
    echo "Warning: No user set, please create a login first then save it to the .settings config"
  fi
  pass=$(grep "^test_pass" .settings | awk 'BEGIN {RS="\n"}{split($0,a,"="); print a[2]}' | sed 's/\r//g')
  if [ $? -ne 0 ]; then
    echo "Warning: No password set, please create a login first then save it to the .settings config"
  fi
fi

test_count=0
test_success=0

# print help message
help() {
  echo "${0##*/}: usage"
  echo "-h        : Shows this usage"
  echo "--help    : Same as -h"
  echo "-H [ip]   : Set target host.  Default localhost"
  echo "-p [port] : Set target port.  Default 8080"
  echo "-s        : Set https mode"
  echo "-v        : Print more sh*t"
  echo "-r        : Print json responses"
  echo "-D        : Destroy token file after script is complete"
  echo "-rl       : Test Rate Limit"
  echo "-l        : Login then exit"
  echo "-L        : Logout then exit"
  echo "-R        : Register account"
  echo "-d [data] : Set curl data (set before -c)"
  echo "-c [cmd]  : Test single api command [cmd]"
  echo "-t        : Are you a teapot?"
}

# test curl response against expected value
test() {
  # Print output if there is any
  if [[ $verbose = "true" || $output = "true" ]]; then
    echo -n "Output = "
    cat $output_file
  fi

  # Increment counters and print result
  ((test_count++))
  echo -n "Done.  Expected $1 got $2 - "
  if [[ $1 == $2 ]]; then
    echo -e "\e[32m✓\e[39m"
    ((test_success++))
  else 
    echo -e "\e[31mX\e[39m"
  fi

  # pretty output by putting a empty line at the end 
  if [[ $verbose = "true" || $output = "true" ]]; then echo "" ; fi

  # Safety to not trigger the rate limiter.
  sleep 1
}

# Process args
while (( $# )); do
  case $1 in
    -h|--help)
      help 
      exit 1
      ;;
    -p)
      port=$2
      shift 1
      ;;
    -H)
      host=$2
      shift 1
      ;;
    -s)
      protocol="https://"
      ;;
    -v)
      verbose=true
      ;;
    -r)
      output=true
      ;;
    -D)
      if [ -f $token_file ]; then
        rm $token_file
        echo "Token deleted"
      fi
      exit 0;
      ;;
    -t)
      curl $([[ $verbose = "true" ]] && echo "-v") -s --header Origin:$protocol$host:$port $protocol$host:$port/teapot/
      exit 418
      ;;
    -rl)
      ratelimit=true
      ;;
    -l)
      if [ -f $token_file ]; then
        echo "Error: Token file exists, you must delete it before trying to login again"
        exit 1;
      fi
      curl $([[ $verbose = "true" ]] && echo "-v") -s --header Origin:$protocol$host:$port $protocol$host:$port/user/login/ -d "uuid=$user&password=$pass" | tee $output_file
      # Save the token
      grep -o '"token": *"[^"]*"' $output_file | grep -o '"[^"]*"$' | sed 's/\"//g' > $token_file
      exit 0;
      ;;
    -L)
      curl $([[ $verbose = "true" ]] && echo "-v") -s --header Origin:$protocol$host:$port $protocol$host:$port/user/logout/ -d "token=$token"
      rm $token_file
      exit 0;
      ;;
    -R)
      curl $([[ $verbose = "true" ]] && echo "-v") -s --header Origin:$protocol$host:$port $protocol$host:$port/user/register/ -d "password=$2&password_confirm=$2" > $output_file
      echo "-- Place these into your .settings file --"
      echo -n "test_user=" && cat $output_file | grep -o '"UUID": *"[^"]*"' | grep -o '"[^"]*"$' | sed 's/\"//g'
      echo "test_pass=$2"
      exit 0;
      ;;
    -d)
      curl_data=$2
      shift 1
      ;;
    -c)
      curl $([[ $verbose = "true" ]] && echo "-v") -s --header Origin:$protocol$host:$port $protocol$host:$port/$2 $([[ $token != "" ]] && echo "-d 'token=$token'") $([[ $curl_data != "" ]] && echo "-d $curl_data")
      exit 0;
      ;;
    *)
      echo "Unknown switch: \"$1\", use -h or --help for a list of switches"
      exit 1
      ;;
  esac

  shift

done

# Set command
cmd="curl $([[ $verbose = "true" ]] && echo "-v") -s -w %{HTTP_CODE} $([[ $verbose = "true" || $output = "true" ]] && echo "-o $output_file" || echo "-o /dev/null" ) --header Origin:$protocol$host:$port $protocol$host:$port"
#echo $cmd"/debug/" ; exit 1

echo "Testing $host:$port .... "
echo "-----------------------------------"

# -----------------------------------------------------------
# Test API integrity
# -----------------------------------------------------------

if [[ $ratelimit == "true" ]]; then
  # Test server rate limiting
  echo "Testing rate limiting..."
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  $cmd > /dev/null
  response=`$cmd`
  test 429 $response
  sleep 1
  #cleanup
  if [ -f $output_file ]; then
    rm $output_file
  fi
  exit 0
fi

# Test origin
echo "Testing no header origin"
test 400 $(curl $([[ $verbose = "true" ]] && echo "-v") -s -w %{HTTP_CODE} $([[ $verbose = "true" || $output = "true" ]] && echo "-o $output_file" || echo "-o /dev/null" ) $protocol$host:$port)
sleep 0.5

# Test invalid origin
echo "Testing invalid origin"
test 400 $(curl $([[ $verbose = "true" ]] && echo "-v") -s -w %{HTTP_CODE} $([[ $verbose = "true" || $output = "true" ]] && echo "-o $output_file" || echo "-o /dev/null" ) $protocol$host:$port --header Origin:http://example.com)


# -----------------------------------------------------------
# Test functions
# -----------------------------------------------------------

# Test no action and get sesssion id
echo "Testing no action to API..."
test 400 $($cmd)

# Test login, no credentials
echo "Testing login with no credentials..."
test 400 $($cmd/user/login)

# Test login, wrong password
echo "Testing login, wrong password..."
test 400 $($cmd/user/login -d "uuid=$user&password=wrongpassword")

# Test logout, not logged in
echo "Testing logout, not logged in..."
test 400 $($cmd/user/logout)

# Test changing password, not logged in
echo "Testing change password, not logged in ..."
test 400 $($cmd/user/newpassword)

# Test changing password, not logged in
echo "Testing change password, not logged in ..."
test 400 $($cmd/user/newpassword)


# ----------------------------------------------
# functions after logged in
# ----------------------------------------------

echo ""
echo "Testing functions while authenticated...."
echo "--------------------------------------------------------"

# Test login, correct password
echo "Testing login, correct password..."
test 200 $($cmd/user/login -d "uuid=$user&password=$pass")

# Testing change password with no data
echo "Testing changing password, no data ..."
test 400 $($cmd/user/newpassword)

# Testing change password, no new password
echo "Testing changing password, no new password ..."
test 400 $($cmd/user/newpassword -d "oldpassword=old")

# Testing change password, no old password
echo "Testing changing password, no old password ..."
test 400 $($cmd/user/newpassword -d "newpassword=old")

# Testing change password, passwords match
echo "Testing changing password, identicle passwords"
test 400 $($cmd/user/newpassword -d "oldpassword=old&newpassword=old")

# Testing change password, wrong old password
echo "Testing changing password, incorrect old password ..."
test 400 $($cmd/user/newpassword -d "oldpassword=old&newpassword=newpassword")

# Testing change password
echo "Testing changing password, incorrect old password ..."
test 200 $($cmd/user/newpassword -d "oldpassword=$pass&newpassword=$pass2")

# Changing password back
echo "Setting password back to old"
$cmd"/user/newpassword" -d "oldpassword=$pass2&newpassword=$pass" > /dev/null

# Test logout, user logged in
echo "Testing logout ..."
test 200 $($cmd/user/logout)


# Final statistics
echo ""
echo "Total tests: $test_count"
echo -n "Successful: $test_success "
printf %.0f%%\\n "$((10**3 * $test_success / $test_count ))e-1"


#cleanup
if [ -f $output_file ]; then
  rm $output_file
fi
