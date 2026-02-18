<?php
/**
 * The main template file – Tour41 theme.
 *
 * @package Tour41
 */

get_header();
?>

<main id="primary" class="site-main">
    <?php
    if ( have_posts() ) :
        while ( have_posts() ) :
            the_post();
            the_title( '<h2>', '</h2>' );
            the_content();
        endwhile;
    else :
        echo '<p>No content found.</p>';
    endif;
    ?>
</main>

<?php
get_footer();
