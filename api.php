<?php 

// TODO: remove this in production
// ====================== DEVELOPMENT PURPOSES ========================== 
session_save_path(getcwd()."/temp/");

// Typical PHP stuff
session_start();

// Include and start the logging system
include "logger.php";

// Include some multipurpose functions and definitions
include "global_functions.php";


// Rate limit requests from a single ip to 5 requests per second by counting log requests
$query = $logger->query("select count(timestamp) from log where IP = \"" . $_SERVER["REMOTE_ADDR"] . "\" and  timestamp = \"" . time() . "\"");
if (intval($query->fetch()[0]) > 5) send_data(TOOMANY);


// Rate limit requests from a single session to 1000 per 24 hours
if (isset($_SESSION["request_reset_timestamp"])) {

  // Increment counter
  if (isset($_SESSION["request_count"])) 
    $_SESSION["request_count"] = $_SESSION["request_count"] + 1;
  else
    $_SESSION["request_count"] = 1;

  // Is the session still within the time before reset and counter is over 1000
  if ($_SESSION["request_reset_timestamp"] > time() && $_SESSION["request_count"] > 999) 
    send_data(TOOMANY);
  
  // Reset items if 
  if (time() > $_SESSION["request_reset_timestamp"]) {
    $_SESSION["request_reset_timestamp"] = strtotime("+1 day", time());
    $_SESSION["request_count"] = 0;
  }

} else {
  $_SESSION["request_reset_timestamp"] = strtotime("+1 day", time());
}


// Limit requests from only specific origins
if (!isset($_SERVER["HTTP_ORIGIN"]) || !array_key_exists($_SERVER["HTTP_ORIGIN"], $origin_whitelist)){
  send_data(BAD);
} 

// Extract URI elements into an array (empty elements excluded, then reindex)
$input = array_values(array_filter(explode("/",$_SERVER["REQUEST_URI"]), 'strlen'));


// Connect to the quiz db
$quizDB = new PDO("sqlite:./quiz.db");


// Load list of functions
include "api_functions.php";

// Set the header to JSON content type
header("Content-Type: text/json");

// Check that there has been a API request
if (!isset($input[0])) {
  send_data(BAD, "Invalid request");
}

// Process input logic
while(1) {

  // Check the item we are processing exists first
  if (!isset($functions[$input[0]]))
    send_data(BAD, "Invalid request"); // The API has been used incorrectly

  // Does the item point to an array?
  if ( is_array($functions[$input[0]]) ) {
    
    // Yes, step further into the array
    $functions = $functions[$input[0]];
    // Pop off the first element of the URI array
    array_shift($input);

    // Loop
    continue;

  // otherwise it must be a function.  There should never be a case where a $function element is neither a array or a function
  } else {

    // Call the function.
    $functions[$input[0]]($quizDB);

    // This should never get called because each function must have a send_data() which includes die(), but as a fallback...
    die(); //Never infinite loop

  }
}