package modelschool.core.model;

enum Gender {
	Male;
	Female;
	Other(?other:String);
	Unknown;
}
