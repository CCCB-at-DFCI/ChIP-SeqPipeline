
//for opening/closing the sample-specific panels in the QC report
$(document).ready(function() {
	$('.accordion-panel').click(function(){
		var panel="_panel"
		var view="_view"
		var target = $(this).attr("id");
		$('#'+target.replace(panel, view)).slideToggle();
	});
});


