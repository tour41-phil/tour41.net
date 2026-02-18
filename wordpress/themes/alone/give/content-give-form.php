<?php
$form_id          = get_the_ID(); // Form ID.
$raw_content      = ''; // Raw form content.
$stripped_content = ''; // Form content stripped of HTML tags and shortcodes.
$excerpt          = ''; // Trimmed form excerpt ready for display.
$excerpt_length   = -1;

?>

<article id="post-<?php the_ID(); ?>" <?php post_class( 'donations-give-form-wrap' ); ?>>

	<?php
	// Maybe display the featured image.
	printf(
		'<div class="give-card__media">%s</div>',
		get_the_post_thumbnail( $form_id, 'medium' )
	);

	?>

	<div class="give-card__body">
		<?php


		// Maybe display the goal progess bar.
		if ( give_is_setting_enabled( get_post_meta( $form_id, '_give_goal_option', true ) ) ) {
				give_show_goal_progress( $form_id );
		}

		// Maybe display the form title.
		printf(
			'<h3 class="give-card__title">
				<a href="%s">%s</a>
			</h3>',
			get_the_permalink(),
			get_the_title()
		);

		// Maybe display the form excerpt.
		if ( has_excerpt( $form_id ) ) {
			// Get excerpt from the form post's excerpt field.
			$raw_content      = get_the_excerpt( $form_id );
			$stripped_content = wp_strip_all_tags(
				strip_shortcodes( $raw_content )
			);
		} else {
			// Get content from the form post's content field.
			$raw_content = give_get_meta( $form_id, '_give_form_content', true );

			if ( ! empty( $raw_content ) ) {
				$stripped_content = wp_strip_all_tags(
					strip_shortcodes( $raw_content )
				);
			}
		}

		// Maybe truncate excerpt.
		if ( 0 < $excerpt_length ) {
			$excerpt = wp_trim_words( $stripped_content, $excerpt_length );
		} else {
			$excerpt = $stripped_content;
		}

		printf( '<p class="give-card__text">%s</p>', $excerpt );

		// Maybe display the form donate button.
		printf(
			'<a id="give-card-%1$s" class="give-card__button js-give-grid-modal-launcher" data-effect="mfp-zoom-out" href="#give-modal-form-%1$s">%2$s</a>',
			esc_attr( $form_id ),
			esc_html__( 'Donate Now', 'alone' )
		);

		?>
	</div>

	<?php
		// If modal, print form in hidden container until it is time to be revealed.
		printf(
			'<div id="give-modal-form-%1$s" class="give-donation-grid-item-form give-modal--slide mfp-hide">',
			$form_id
		);
		give_get_donation_form( $form_id );
		echo '</div>';
	?>

</article>
