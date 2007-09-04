/*
 * org.openmicroscopy.shoola.agents.measurement.util.AnnotationDescription 
 *
  *------------------------------------------------------------------------------
 *  Copyright (C) 2006-2007 University of Dundee. All rights reserved.
 *
 *
 * 	This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 *------------------------------------------------------------------------------
 */
package org.openmicroscopy.shoola.agents.measurement.util;

import java.util.HashMap;


//Java imports

//Third-party libraries
import org.jhotdraw.draw.AttributeKey;
import org.jhotdraw.draw.AttributeKeys;

//Application-internal dependencies
import org.openmicroscopy.shoola.util.roi.model.annotation.AnnotationKey;
import org.openmicroscopy.shoola.util.roi.model.annotation.AnnotationKeys;
import org.openmicroscopy.shoola.util.roi.model.annotation.MeasurementAttributes;

/** 
 * 
 *
 * @author  Jean-Marie Burel &nbsp;&nbsp;&nbsp;&nbsp;
 * 	<a href="mailto:j.burel@dundee.ac.uk">j.burel@dundee.ac.uk</a>
 * @author	Donald MacDonald &nbsp;&nbsp;&nbsp;&nbsp;
 * 	<a href="mailto:donald@lifesci.dundee.ac.uk">donald@lifesci.dundee.ac.uk</a>
 * @version 3.0
 * <small>
 * (<b>Internal version:</b> $Revision: $Date: $)
 * </small>
 * @since OME3.0
 */
public class AnnotationDescription
{	

	/** Description of the roi id. */
	public final static String ROIID_STRING = "ROI ID";
	
	/** Description of the time point. */
	public final static String TIME_STRING = "T";
	
	/** Description of the Z section. */
	public final static String ZSECTION_STRING = "Z";
	
	/** Description of the shape string. */
	public final static String SHAPE_STRING = "Shape";
	
	/** 
	 * The map of annotations/attributes to text descriptions in 
	 * inspector, manager and results windows. 
	 */
	public final static HashMap<AttributeKey, String>	annotationDescription;
	static
	{
		annotationDescription=new HashMap<AttributeKey, String>();
		annotationDescription.put(AnnotationKeys.BASIC_TEXT, "Annotation");
		annotationDescription.put(AnnotationKeys.ANGLE, "Angle");
		annotationDescription.put(AnnotationKeys.AREA, "Area");
		annotationDescription.put(AnnotationKeys.CENTREX, "Centre(X)");
		annotationDescription.put(AnnotationKeys.CENTREY, "Centre(Y)");
		annotationDescription.put(AnnotationKeys.ENDPOINTX, "EndCoord(X)");
		annotationDescription.put(AnnotationKeys.ENDPOINTY, "EndCoord(Y)");
		annotationDescription.put(AnnotationKeys.STARTPOINTX, "StartCoord(X)");
		annotationDescription.put(AnnotationKeys.STARTPOINTY, "StartCoord(Y)");
		annotationDescription.put(AnnotationKeys.HEIGHT, "Height");
		annotationDescription.put(AnnotationKeys.WIDTH, "Width");
		annotationDescription.put(AnnotationKeys.LENGTH, "Length");
		annotationDescription.put(AnnotationKeys.PERIMETER, "Perimeter");
		annotationDescription.put(AnnotationKeys.POINTARRAYX, "Coord List(X)");
		annotationDescription.put(AnnotationKeys.POINTARRAYY, "Coord List(Y)");
		annotationDescription.put(AnnotationKeys.VOLUME, "Volume");
		annotationDescription.put(AttributeKeys.FILL_COLOR, "Fill Colour");
		annotationDescription.put(AttributeKeys.FONT_SIZE, "Font Size");
		annotationDescription.put(AttributeKeys.STROKE_COLOR, "Line Colour");
		annotationDescription.put(AttributeKeys.STROKE_WIDTH, "Line Width");
		annotationDescription.put(AttributeKeys.TEXT_COLOR, "Font Colour");
		annotationDescription.put(MeasurementAttributes.MEASUREMENTTEXT_COLOUR,
														"Measurement Colour");
		annotationDescription.put(MeasurementAttributes.SHOWMEASUREMENT,
														"Show Measurement");
		}
}


