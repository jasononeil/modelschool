package modelschool.core.model;

typedef ContactDetails = Array<ContactDetail>;

enum ContactDetail {
	Phone( number:String, name:Null<String> );
	Email( email:String, name:Null<String> );
}

class ContactDetailTools {
	public static function getDetail( detail:ContactDetail ):{ name:String, link:String, text:String } {
		return switch detail {
			case Phone( number, name ) if ( name==null ): { name: 'Phone', link: 'tel:$number', text: number }
			case Phone( number, name ): { name: 'Phone ($name)', link: 'tel:$number', text: number }
			case Email( email, name ) if ( name==null ): { name: 'Email', link: 'mailto:$email', text: email }
			case Email( email, name ): { name: 'Email ($name)', link: 'mailto:$email', text: email }
		};
	}
}