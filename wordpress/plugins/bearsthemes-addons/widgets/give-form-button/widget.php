<?php
namespace BearsthemesAddons\Widgets\Give_Form_Button;

use Elementor\Widget_Base;
use Elementor\Controls_Manager;
use Elementor\Group_Control_Typography;
use Elementor\Group_Control_Background;
use Elementor\Group_Control_Border;
use Elementor\Group_Control_Box_Shadow;

if ( ! defined( 'ABSPATH' ) ) exit; // Exit if accessed directly

class Be_Give_Form_Button extends Widget_Base {

	public function get_name() {
		return 'be-give-form-button';
	}

	public function get_title() {
		return __( 'Be Give Form Button', 'bearsthemes-addons' );
	}

	public function get_icon() {
		return 'eicon-button';
	}

	public function get_categories() {
		return [ 'bearsthemes-addons' ];
	}

	public function get_script_depends() {
		return [ 'bearsthemes-addons' ];
	}

	protected function get_supported_post_ids() {
		$supported_taxonomies = [];

		$args = array(
			'post_type' => 'give_forms',
			'post_status'    => 'publish',
		);

		$query = new \WP_Query( $args );
		if ( $query->have_posts() ) :
			while ( $query->have_posts() ) : $query->the_post();
			$supported_taxonomies[get_the_ID()] = get_the_title();
			endwhile;
	 		wp_reset_postdata();
	 	endif;

		return $supported_taxonomies;
	}

	protected function register_layout_section_controls() {
		$this->start_controls_section(
			'section_layout',
			[
				'label' => __( 'Layout', 'bearsthemes-addons' ),
			]
		);

		$this->add_control(
      'form_button_text',
      [
        'label' => __( 'Button Text', 'bearsthemes-addons' ),
        'label_block' => true,
        'type' => Controls_Manager::TEXT,
        'default' => __( 'Donate Now', 'bearsthemes-addons' ),
      ]
    );

		$this->add_control(
			'form_id',
			[
				'label' => __( 'Form Id', 'bearsthemes-addons' ),
				'type' => Controls_Manager::SELECT,
				'options' => $this->get_supported_post_ids(),
			]
		);

		$this->add_control(
			'form_skin',
			[
				'label' => __( 'Form Skin', 'bearsthemes-addons' ),
				'type' => Controls_Manager::SELECT,
				'default' => 'skin-default',
				'options' => [
					'skin-default' => __( 'Default', 'bearsthemes-addons' ),
					'skin-pumori' => __( 'Pumori', 'bearsthemes-addons' ),
					'skin-baruntse' => __( 'Baruntse', 'bearsthemes-addons' ),
					'skin-coropuna' => __( 'Coropuna', 'bearsthemes-addons' ),
					'skin-andrus' => __( 'Andrus', 'bearsthemes-addons' ),
					'skin-saltoro' => __( 'Saltoro', 'bearsthemes-addons' ),
					'skin-hardeol' => __( 'Hardeol', 'bearsthemes-addons' ),
					'skin-batura' => __( 'Batura', 'bearsthemes-addons' ),
					'skin-nevado' => __( 'Nevado', 'bearsthemes-addons' ),
					'skin-cholatse' => __( 'Cholatse', 'bearsthemes-addons' ),
					'skin-paradis' => __( 'Paradis', 'bearsthemes-addons' ),
					'skin-castor' => __( 'Castor', 'bearsthemes-addons' ),
					'skin-grouse' => __( 'Grouse', 'bearsthemes-addons' ),
					'skin-michelson' => __( 'Michelson', 'bearsthemes-addons' ),
					'skin-cerredo' => __( 'Cerredo', 'bearsthemes-addons' ),
					'skin-gangri' => __( 'Gangri', 'bearsthemes-addons' ),
					'skin-manaslu' => __( 'Manaslu', 'bearsthemes-addons' ),
					'skin-ampato' => __( 'Ampato', 'bearsthemes-addons' ),
					'skin-jorasses' => __( 'Jorasses', 'bearsthemes-addons' ),
					'skin-tronador' => __( 'Tronador', 'bearsthemes-addons' ),
					'skin-vaccine' => __( 'Vaccine', 'bearsthemes-addons' ),
					'skin-yutmaru' => __( 'Yutmaru', 'bearsthemes-addons' ),
					'skin-jimara' => __( 'Jimara', 'bearsthemes-addons' ),
				],
			]
		);

		$this->end_controls_section();
	}

	protected function register_design_latyout_section_controls() {
		$this->start_controls_section(
			'section_design_layout',
			[
				'label' => __( 'Layout', 'bearsthemes-addons' ),
				'tab' => Controls_Manager::TAB_STYLE,
			]
		);

		$this->add_responsive_control(
			'alignment',
			[
				'label' => __( 'Alignment', 'bearsthemes-addons' ),
				'type' => Controls_Manager::CHOOSE,
				'options' => [
					'left' => [
						'title' => __( 'Left', 'bearsthemes-addons' ),
						'icon' => 'eicon-text-align-left',
					],
					'center' => [
						'title' => __( 'Center', 'bearsthemes-addons' ),
						'icon' => 'eicon-text-align-center',
					],
					'right' => [
						'title' => __( 'Right', 'bearsthemes-addons' ),
						'icon' => 'eicon-text-align-right',
					],
				],
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal' => 'text-align: {{VALUE}};',
				],
			]
		);

    $this->add_group_control(
      Group_Control_Typography::get_type(),
      [
        'name' => 'give_btn_typography',
        'default' => '',
        'selector' => '{{WRAPPER}} .give-form-wrap .give-btn-modal',
      ]
    );

    $this->start_controls_tabs( 'tabs_button_style' );

		$this->start_controls_tab(
			'tab_button_normal',
			[
				'label' => __( 'Normal', 'bearsthemes-addons' ),
			]
		);

    $this->add_control(
			'button_text_color',
			[
				'label' => __( 'Text Color', 'bearsthemes-addons' ),
				'type' => Controls_Manager::COLOR,
				'default' => '',
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal' => 'fill: {{VALUE}}; color: {{VALUE}};',
				],
			]
		);

		$this->add_group_control(
			Group_Control_Background::get_type(),
			[
				'name' => 'background',
				'label' => __( 'Background', 'bearsthemes-addons' ),
				'types' => [ 'classic', 'gradient' ],
				'exclude' => [ 'image' ],
				'selector' => '{{WRAPPER}} .give-form-wrap .give-btn-modal',
				'fields_options' => [
					'background' => [
						'default' => 'classic',
					],
					'color' => [
						'global' => [
							'type' => Controls_Manager::COLOR,
						],
					],
				],
			]
		);

		$this->end_controls_tab();

		$this->start_controls_tab(
			'tab_button_hover',
			[
				'label' => __( 'Hover', 'bearsthemes-addons' ),
			]
		);

		$this->add_control(
			'hover_color',
			[
				'label' => __( 'Text Color', 'bearsthemes-addons' ),
				'type' => Controls_Manager::COLOR,
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal:hover, {{WRAPPER}} .give-form-wrap .give-btn-modal:focus' => 'color: {{VALUE}};',
					'{{WRAPPER}} .give-form-wrap .give-btn-modal:hover svg, {{WRAPPER}} .give-form-wrap .give-btn-modal:focus svg' => 'fill: {{VALUE}};',
				],
			]
		);

		$this->add_group_control(
			Group_Control_Background::get_type(),
			[
				'name' => 'button_background_hover',
				'label' => __( 'Background', 'bearsthemes-addons' ),
				'types' => [ 'classic', 'gradient' ],
				'exclude' => [ 'image' ],
				'selector' => '{{WRAPPER}} .give-form-wrap .give-btn-modal:hover, {{WRAPPER}} .give-form-wrap .give-btn-modal:focus',
				'fields_options' => [
					'background' => [
						'default' => 'classic',
					],
				],
			]
		);

		$this->add_control(
			'button_hover_border_color',
			[
				'label' => __( 'Border Color', 'bearsthemes-addons' ),
				'type' => Controls_Manager::COLOR,
				'condition' => [
					'border_border!' => '',
				],
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal:hover, {{WRAPPER}} .give-form-wrap .give-btn-modal:focus' => 'border-color: {{VALUE}};',
				],
			]
		);

		$this->end_controls_tab();

		$this->end_controls_tabs();

		$this->add_group_control(
			Group_Control_Border::get_type(),
			[
				'name' => 'border',
				'selector' => '{{WRAPPER}} .give-form-wrap .give-btn-modal',
				'separator' => 'before',
			]
		);

		$this->add_control(
			'border_radius',
			[
				'label' => __( 'Border Radius', 'bearsthemes-addons' ),
				'type' => Controls_Manager::DIMENSIONS,
				'size_units' => [ 'px', '%', 'em' ],
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal' => 'border-radius: {{TOP}}{{UNIT}} {{RIGHT}}{{UNIT}} {{BOTTOM}}{{UNIT}} {{LEFT}}{{UNIT}};',
				],
			]
		);

		$this->add_group_control(
			Group_Control_Box_Shadow::get_type(),
			[
				'name' => 'button_box_shadow',
				'selector' => '{{WRAPPER}} .give-form-wrap .give-btn-modal',
			]
		);

		$this->add_responsive_control(
			'text_padding',
			[
				'label' => __( 'Padding', 'bearsthemes-addons' ),
				'type' => Controls_Manager::DIMENSIONS,
				'size_units' => [ 'px', 'em', '%' ],
				'selectors' => [
					'{{WRAPPER}} .give-form-wrap .give-btn-modal' => 'padding: {{TOP}}{{UNIT}} {{RIGHT}}{{UNIT}} {{BOTTOM}}{{UNIT}} {{LEFT}}{{UNIT}};',
				],
			]
		);
    $this->add_responsive_control(
      'text_margin',
      [
        'label' => __( 'Margin', 'bearsthemes-addons' ),
        'type' => Controls_Manager::DIMENSIONS,
        'size_units' => [ 'px', 'em', '%' ],
        'selectors' => [
          '{{WRAPPER}} .give-form-wrap .give-btn-modal' => 'margin: {{TOP}}{{UNIT}} {{RIGHT}}{{UNIT}} {{BOTTOM}}{{UNIT}} {{LEFT}}{{UNIT}};',
        ],
      ]
    );


		$this->end_controls_section();
	}

	protected function register_design_form_section_controls() {
		$this->start_controls_section(
			'section_design_form',
			[
				'label' => __( 'Popup Form', 'bearsthemes-addons' ),
				'tab' => Controls_Manager::TAB_STYLE,
				'condition' => [
					'form_id!'=> '',
				],
			]
		);

		$this->add_control(
			'form_main_color',
			[
				'label' => __( 'Main Color', 'bearsthemes-addons' ),
				'type' => Controls_Manager::COLOR,
				'default' => '',
				'selectors' => [
					'.mfp-wrap form.give-form .give-total-wrap #give-amount,
					 .mfp-wrap form.give-form #give-donation-level-button-wrap .give-btn:not(.give-default-level):hover,
					 .mfp-wrap form.give-form #give-gateway-radio-list > li label:hover,
					 .mfp-wrap form.give-form #give-gateway-radio-list > li.give-gateway-option-selected label,
					 .mfp-wrap form.give-form #give_terms_agreement label:hover,
					 .mfp-wrap form.give-form #give_terms_agreement input[type=checkbox]:checked + label,
					 .mfp-wrap form.give-form .give_terms_links,
					 .mfp-wrap form.give-form #give-final-total-wrap .give-final-total-amount' => 'color: {{VALUE}};',
					'.mfp-wrap form.give-form .give-total-wrap .give-currency-symbol,
					 .mfp-wrap form.give-form #give-donation-level-button-wrap .give-btn.give-default-level,
					 .mfp-wrap form.give-form #give-gateway-radio-list > li.give-gateway-option-selected label:after,
					 .mfp-wrap form.give-form #give_terms_agreement input[type=checkbox]:checked + label:before,
					 .mfp-wrap form.give-form #give-final-total-wrap .give-donation-total-label,
					 .mfp-wrap form.give-form .give-submit' => 'background-color: {{VALUE}};',
					'.mfp-wrap form.give-form #give-donation-level-button-wrap .give-btn:hover,
					 .mfp-wrap form.give-form #give-donation-level-button-wrap .give-btn.give-default-level,
					 .mfp-wrap form.give-form #give_terms_agreement input[type=checkbox]:checked + label:before' => 'border-color: {{VALUE}};',
					'.mfp-wrap form.give-form .give_terms_links' => 'box-shadow: 0px 1px 0px {{VALUE}};',
				]
			]
		);

		$this->add_control(
			'form_main_color_hover',
			[
				'label' => __( 'Main Color Hover', 'bearsthemes-addons' ),
				'type' => Controls_Manager::COLOR,
				'default' => '',
				'selectors' => [
					'.mfp-wrap form.give-form .give-submit:hover' => 'background-color: {{VALUE}};',
				],
			]
		);

		$this->add_group_control(
			Group_Control_Typography::get_type(),
			[
				'name' => 'form_typography',
				'label' => __( 'Typography', 'bearsthemes-addons' ),
				'default' => '',
				'selector' => '.mfp-wrap form.give-form',
			]
		);

		$this->end_controls_section();
	}

	protected function register_controls() {
		$this->register_layout_section_controls();

		$this->register_design_latyout_section_controls();
		$this->register_design_form_section_controls();
	}

	public function get_instance_value_skin( $key ) {
		$settings = $this->get_settings_for_display();

		if( !empty( $settings['_skin'] ) && isset( $settings[str_replace( '-', '_', $settings['_skin'] ) . '_' . $key] ) ) {
			 return $settings[str_replace( '-', '_', $settings['_skin'] ) . '_' . $key];
		}
		return $settings[$key];
	}

	public function render_loop_header() {
		$settings = $this->get_settings_for_display();

		$classes = 'elementor-give-form';

		?>
			<div class="<?php echo esc_attr( $classes ); ?>">
		<?php
	}

	public function render_loop_footer() {

		?>
			</div>
		<?php
	}

	protected function render() {
		$settings = $this->get_settings_for_display();

		$this->render_loop_header();

		$atts = array(
			'id' => $settings['form_id'],  // integer.
			'show_title' => false, // boolean.
			'show_goal' => false, // boolean.
			'show_content' => 'none', //above, below, or none
			'display_style' => 'button', //modal, button, and reveal
			'continue_button_title' => $settings['form_button_text'] //string

		);

		if( !empty( $settings['form_id'] ) ) {
			echo '<div class="elementor-give-modal-wrap" data-skin="elementor-give-modal--' . $settings['form_skin'] . '">';
				give_get_donation_form( $atts );
			echo '</div>';
		}

		$this->render_loop_footer();

	}

	protected function content_template() {

	}
}
