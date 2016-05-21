package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import modelschool.core.model.*;

class District extends Object
{
	public var name:SString<255>;
	public var schools:HasMany<School>;
}
