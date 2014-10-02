package modelschool.assessments.model;

import ufront.db.Object;
import modelschool.core.model.*;
import sys.db.Types;

class Assessment extends Object {

	public var semester:STinyUInt = 0;
	public var order:STinyUInt = 0;

	@:validate( _.length>0, "Assignment name must be at least 1 letter or number long" )
	public var name:SString<255> = "";

	public var schoolClass:BelongsTo<SchoolClass>;

	@:validate( _>0 && _<=255, "'Out of' must be between 0 and 255" )
	public var outOf:STinyUInt = 100;

	@:validate( _>=0 && _<=100, "Weighting must be between 0 and 100" )
	public var weighting:Float = 20;

	public var startDate:SDate;
	public var dueDate:SDate;

	public var results:HasMany<AssessmentResult>;

	/**
		Use associated results to calculate an average.

		If on the client, please call `loadRelations()` first so we know the results are ready to use.
	**/
	@:skip public var average(get,never):Float;
	function get_average() {
		var total:Float = 0,
			numMarked = 0;
		for ( result in results ) if ( result.isMarked ) {
			numMarked++;
			total += result.mark;
		}
		return (numMarked!=0) ? total / numMarked : 0;
	}
}
