package modelschool.assessments.model;

import ufront.db.Object;
import modelschool.core.model.*;
import modelschool.assessments.model.*;
import sys.db.Types;

class AssessmentResult extends Object {

	public var assessment:BelongsTo<Assessment>;
	public var student:BelongsTo<Student>;
	
	public var acknowledgedByParent:Null<BelongsTo<Parent>>;
	public var acknowledgedByDate:SDateTime;

	@:validate( _!=Math.NaN && _>=0 && _<=assessment.outOf, "Mark must be a number between 0 and "+assessment.outOf )
	public var mark:Null<Float>;

	@:skip public var isMarked(get,never):Bool;
	inline function get_isMarked() return ( mark!=null && !Math.isNaN(mark) );

	/**
		Get the mark as a percentage, rounded to the nearest whole number.
	**/
	public function getNearestPercentage():Int {
		return Math.round( mark / assessment.outOf * 100 );
	}

	/**
		Given an array of results, get a cumulative score for that student.

		Only results where `isMarked==true` will be included.
		If a result is not included, it's weighting is not included either.
		It is as if the assessment did not happen, rather than the student getting 0 for the assessment.

		Returns a float between 0 and 100
	**/
	public static function getWeightedTotal( results:Iterable<AssessmentResult> ):Float {
		var marks = 0.0;
		var total = 0.0;
		for ( result in results ) {
			var assessment = result.assessment;
			if ( result!=null && result.isMarked ) {
				marks += (result.mark/assessment.outOf) * assessment.weighting;
				total += assessment.weighting;
			}
		}
		return (total!=0) ? marks / total * 100 : 0;
	}

	/**
		Get average mark for assessments.  Assumes the results are all for the same assessment.

		Returns a float between 0 and the `assessment.outOf` value
	**/
	public static function getAssessmentAverage( results:Iterable<AssessmentResult> ):Float {
		var total = 0.0;
		var numResults = 0;
		for ( result in results ) {
			if ( result.isMarked ) {
				total += result.mark;
				numResults++;
			}
		}
		return (numResults!=0) ? total/numResults : 0;
	}

	/**
		Get class average for year.

		Takes an `Iterable<Iterable<AssessmentResult>>`, in this case `StudentArray<AssessmentArray<AssessmentResult>>`

		It finds the mean of all student's weighted averages.

		Returns a float between 0 and 100.
	**/
	public static function getWeightedClassAverages( allResults:Iterable<Iterable<AssessmentResult>> ):Float {
		var total = 0.0;
		var numStudents = 0;
		for ( studentResults in allResults ) {
			var studentAverage = getWeightedTotal( studentResults );
			total += studentAverage;
			numStudents++;
		}
		return (numStudents!=0) ? total/numStudents : 0;
	}
}
