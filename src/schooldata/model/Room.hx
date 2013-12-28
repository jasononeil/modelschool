package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;

import app.coredata.model.*;

class Room extends Object
{
	public var name:SString<10>;
	public var description:Null<SString<50>>;
}