<?php 

add_action('elementor/query/blog_desc', function( $query ) {
    if ( ! $query instanceof WP_Query ) return;

    // Neueste zuerst
    $query->set('orderby', 'date');
    $query->set('order', 'DESC');

    // Sticky Posts sollen nicht dazwischenfunken
    $query->set('ignore_sticky_posts', 1);

    // Optional, falls Plugins/Theme die Sortierung via Filter überschreiben:
    $query->set('suppress_filters', true);
});

add_theme_support('hero-image');
add_image_size('hero-image size', 800, 500);


//Dequeue Styles
function project_dequeue_unnecessary_styles() {
	wp_dequeue_style('dashicons');
	wp_deregister_style('dashicons');
	wp_dequeue_style('linecons');
	wp_deregister_style('linecons');
}

//add_action( 'wp_print_styles', 'project_dequeue_unnecessary_styles' );

if ( ! defined( 'FW' ) ) {
	die( 'Forbidden' );
}
/**
 * Theme config
 *
 * @var array $cfg Fill this array with configuration data
 */
