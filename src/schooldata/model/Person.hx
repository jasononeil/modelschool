package schooldata.model;

import sys.db.Types;
import ufront.db.Object;

import schooldata.model.*;
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
}

enum Gender 
{
	Male;
	Female;
	Other;
	Unknown;
}