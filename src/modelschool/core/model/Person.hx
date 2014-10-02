package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;

import modelschool.core.model.*;
import ufront.auth.model.User;

class Person extends Object
{
	public var firstName:SString<30>;
	public var middleNames:Null<SString<30>>;
	public var preferredName:Null<SString<30>>;
	public var surname:SString<30>;
	public var gender:SEnum<Gender>;
	public var birthday:Null<SDate>;
	public var user:BelongsTo<User>;

	@:skip public var preferredFirstName(get,never):String;

	override public function toString() {
		return '$preferredFirstName $surname';
	}

	function get_preferredFirstName():String {
		return preferredName!=null ? preferredName : firstName;
	}
}

enum Gender 
{
	Male;
	Female;
	Other;
	Unknown;
}