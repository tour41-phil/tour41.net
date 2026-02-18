<?php
/**
 * Tour41 theme functions and definitions.
 *
 * @package Tour41
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Theme setup.
 */
function tour41_setup() {
    add_theme_support( 'title-tag' );
    add_theme_support( 'post-thumbnails' );
    add_theme_support( 'html5', array( 'search-form', 'gallery', 'caption' ) );
}
add_action( 'after_setup_theme', 'tour41_setup' );

/**
 * Enqueue styles.
 */
function tour41_scripts() {
    wp_enqueue_style(
        'tour41-style',
        get_stylesheet_uri(),
        array(),
        wp_get_theme()->get( 'Version' )
    );
}
add_action( 'wp_enqueue_scripts', 'tour41_scripts' );
