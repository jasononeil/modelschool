package schooldata.tools;
import schooldata.model.Period;
import schooldata.model.ClassTime;
import schooldata.model.PrimaryOrHigh;
using tink.CoreApi;
using Lambda;
using Dates;

class PeriodTools
{
	public static function classPeriodsOnly(periods:Array<Period>, primaryOrHigh:Either<Int,PrimaryOrHigh>, classTimes:Iterable<ClassTime>) {
		// We want this period included if it is for this yeargroup and it has class data associated with it
		var yeargroup = switch (primaryOrHigh) {
			case Left( yr ): yr;
			case Right( primaryOrSecondary ): yrToCheck( primaryOrSecondary );
		}

		return periods.filter( 
			function (p) {
				if ( !p.yeargroups.has( yeargroup ) ) return false;
				if ( classTimes.filter(
					function (c) return c.periodID == p.id
				).length == 0 ) return false;
				return true;
			}
		);
	}

	public inline static function filterByYeargroup(periods:Array<Period>, yeargroup:Int) {
		return periods.filter( 
			function (p) return p.yeargroups.has(yeargroup) 
		);
	}

	public static function filterByPrimaryOrSecondary(periods:Array<Period>, primaryOrSecondary:PrimaryOrHigh) {
		return periods.filter( 
			function (p) return p.yeargroups.has( yrToCheck(primaryOrSecondary) ) 
		);
	}

	static inline function yrToCheck( primaryOrSecondary ) {
		return switch primaryOrSecondary {
			case Primary: AppConfig.primaryYears()[0];
			case Secondary: AppConfig.secondaryYears()[0];
		}
	}

	public inline static function sortPeriods(periods:Array<Period>) {
		periods.sort( 
			function (p1,p2) return Reflect.compare(p1.position, p2.position) 
		);
		return periods;
	}

	/**
		Get all the periods between a start period and an end period (possibly on a different day), inclusive.

		Params:
		- periods - the periods we are including in our range.  If you only want class periods, only include class periods here
	**/
	public static function range( periods:Array<Period>, startDate:Date, startPeriod:Period, endDate:Date, endPeriod:Period ):Array<Pair<Date,Period>> {
		var date:Date = Date.fromTime( startDate.getTime().snap("day",-1) );
		var currentPeriod:Int = periods.indexOf( startPeriod );
		var indexOfEndPeriod:Int = periods.indexOf( endPeriod );
		var finalPeriod:Int = periods.length - 1;
		var endDate:Float = endDate.getTime().snap("day",-1);

		var range = [];

		var finished = false;
		do {
			var period:Period = periods[currentPeriod];

			var dayOfWeek = date.getDay();
			if ( dayOfWeek>0 && dayOfWeek<6 ) range.push( new Pair(date,period) );

			// Is there another period in this day?
			if ( currentPeriod==indexOfEndPeriod && date.getTime()==endDate ) {
				finished = true;
			}
			else if ( currentPeriod==finalPeriod ) {
				// next day
				date = date.nextDay();
				currentPeriod = 0;
			}
			else {
				// next period, same day
				currentPeriod++;
			}
		}
		while ( finished==false );

		return range;
	}
}

class PeriodToolsOnIter 
{
	public inline static function filterByYeargroup(periodsIt:Iterable<Period>, yeargroup:Int) {
		return PeriodTools.filterByYeargroup( periodsIt.array(), yeargroup );
	}

	public inline static function sortPeriods(periodsIt:Iterable<Period>) {
		return PeriodTools.sortPeriods( periodsIt.array() );
	}

	public inline static function classPeriodsOnly(periodsIt:Iterable<Period>, yeargroup:Int, classTimes:Iterable<ClassTime>) {
		return PeriodTools.classPeriodsOnly( periodsIt.array(), Left(yeargroup), classTimes );
	}
}