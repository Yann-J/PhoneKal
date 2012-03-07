

var PhoneKal = function() { 
	this.resultCallback = null; // Function
}


PhoneKal.prototype.presentPicker = function(options, cb) {
	var now = new Date();
	var nowString = ""+(now.getFullYear())+"-"+(now.getMonth()+1)+"-"+(now.getDate());
	var defaults = {
		initialDate: nowString,
		title: 'Select Date',
		displayTodayButton: true
	}
	
	for (var key in defaults) {
		if (typeof options[key] == "undefined")
			options[key] = defaults[key];
	}

	this.resultCallback = cb;
	return PhoneGap.exec("PhoneKal.presentPicker", options);
};

PhoneKal.prototype.didSelectDate = function(date) {
	this.resultCallback(date);
};

PhoneGap.addConstructor(function() 
{
	if(!window.plugins)
	{
		window.plugins = {};
	}
	window.plugins.PhoneKal = new PhoneKal();
});
