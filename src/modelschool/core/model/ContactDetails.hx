package modelschool.core.model;

typedef ContactDetails = Array<ContactDetail>;

enum ContactDetail {
	Phone( number:String, name:Null<String> );
	Email( email:String, name:Null<String> );
}

class ContactDetailTools {
	/**
		Extract a ContactDetail into an anonymous object
	**/
	public static function getDetail( detail:ContactDetail ):{ name:String, link:String, text:String } {
		return switch detail {
			case Phone( number, name ) if ( name==null ): { name: 'Phone', link: 'tel:$number', text: number }
			case Phone( number, name ): { name: 'Phone ($name)', link: 'tel:$number', text: number }
			case Email( email, name ) if ( name==null ): { name: 'Email', link: 'mailto:$email', text: email }
			case Email( email, name ): { name: 'Email ($name)', link: 'mailto:$email', text: email }
		};
	}

	/**
		Return an array of all phone numbers in somebody's contact details.
	**/
	public static function getPhoneNumbers( details:ContactDetails ):Array<{ name:String, link:String, text:String }> {
		var phoneNumbers = [];
		for ( detail in details )
			if ( detail.match(Phone(_,_)) )
				phoneNumbers.push( getDetail(detail) );
		return phoneNumbers;
	}

	/**
		Return an array of all phone numbers in somebody's contact details.
	**/
	public static function getEmails( details:ContactDetails ):Array<{ name:String, link:String, text:String }> {
		var emails = [];
		for ( detail in details )
			if ( detail.match(Email(_,_)) )
				emails.push( getDetail(detail) );
		return emails;
	}

	/**
		Return the first phone number found.
	**/
	public static function getFirstPhoneNumber( details:ContactDetails ):Null<String> {
		for ( detail in details ) {
			switch detail {
				case Phone(num,_):
					return num;
				case _:
			}
		}
		return null;
	}
}
