/*
 * pojos.ChannelData 
 *
 *------------------------------------------------------------------------------
 *  Copyright (C) 2006-2008 University of Dundee. All rights reserved.
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
package pojos;



//Java imports

//Third-party libraries

//Application-internal dependencies
import omero.RDouble;
import omero.RFloat;
import omero.RInt;
import omero.RString;
import omero.model.AcquisitionMode;
import omero.model.Channel;
import omero.model.ChannelI;
import omero.model.ContrastMethod;
import omero.model.Illumination;
import omero.model.LogicalChannel;
import omero.model.StatsInfo;

/** 
 * The data that makes up an <i>OME</i> Channel along with links to its logical 
 * channel.
 *
 * @author  Jean-Marie Burel &nbsp;&nbsp;&nbsp;&nbsp;
 * <a href="mailto:j.burel@dundee.ac.uk">j.burel@dundee.ac.uk</a>
 * @author Donald MacDonald &nbsp;&nbsp;&nbsp;&nbsp;
 * <a href="mailto:donald@lifesci.dundee.ac.uk">donald@lifesci.dundee.ac.uk</a>
 * @version 3.0
 * <small>
 * (<b>Internal version:</b> $Revision: $Date: $)
 * </small>
 * @since 3.0-Beta4
 */
public class ChannelData 
	extends DataObject
{

	/** Identifies the {@link Channel#ANNOTATIONLINKS} field. */
    public final static String ANNOTATIONS = ChannelI.ANNOTATIONLINKS;
    
    /** The index of the channel. */
    private int 			index;
    
    /** The acquisition mode. */
    private AcquisitionMode mode;
    
    /** The illumination. */
    private Illumination	illumination;
    
    /** The contrast method. */
    private ContrastMethod	contrastMethod;
    
	/** 
	 * Creates a new instance. 
	 * 
	 * @param index The index of the channel.
	 */
    public ChannelData(int index)
    {
        setDirty(false);
        setValue(new ChannelI());
        this.index = index;
    }
    
    /**
     * Creates a new instance.
     * 
     * @param index 	The index of the channel.
     * @param channel 	Back pointer to the {@link Channel} model object. 
     * 					Mustn't be <code>null</code>.
     * @throws IllegalArgumentException If the object is <code>null</code>.
     */
    public ChannelData(int index, Channel channel)
    {
        if (channel == null) 
            throw new IllegalArgumentException("Object cannot null.");
        this.index = index;
        setValue(channel);
        setDirty(false);
    }
    
    /**
     * Returns the channel's index.
     * 
     * @return See above.
     */
    public int getIndex() { return index; }
    
    /**
     * Returns the label of the channel.
     * Following the specification: Name>Fluor>Emission wavelength>index.
     * 
     * @return See above.
     */
    public String getChannelLabeling()
    {
    	String value = getName();
    	if (value != null && value.trim().length() != 0) return value;
    	value = getFluor(); 
    	if (value != null && value.trim().length() != 0) return value;
    	float v = getEmissionWavelength();
    	if (v > 0) return ""+v;
    	return ""+index;
    }
    // Immutables

    /**
     * Sets the name of the logical channel.
     * 
     * @param name The name of the channel.
     */
    public void setName(String name)
    {
        if (name == null) return;
        setDirty(true);
        asChannel().getLogicalChannel().setName(omero.rtypes.rstring(name));
    }

    /**
     * Returns the name of the channel.
     * 
     * @return See above.
     */
    public String getName()
    {
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return null;
        omero.RString n = lc.getName();
        if (n != null) return n.getValue();
        return null;
    }
    
    /**
     * Returns the emission wavelength of the channel.
     * 
     * @return See above
     */
    public float getEmissionWavelength()
    { 
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return index;
    	RFloat value  = lc.getEmissionWave();
		if (value != null) return value.getValue();
		return -1;
    }
    
    /**
     * Returns the excitation wavelength of the channel.
     * 
     * @return See above
     */
    public float getExcitationWavelength()
    { 
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return getEmissionWavelength();
    	RFloat value = lc.getExcitationWave();
    	if (value != null) return value.getValue();
    	return -1;
    }
    
    /**
     * Returns the pin hole size of the channel.
     * 
     * @return See above
     */
    public double getPinholeSize()
    { 
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return -1;
    	RDouble value = lc.getPinHoleSize();
    	if (value != null) return value.getValue();
    	return -1; 
    }
    
    /**
     * Returns the ND filter wavelength of the channel.
     * 
     * @return See above
     */
    public double getNDFilter()
    {
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return -1;
    	RDouble value = lc.getNdFilter();
    	if (value != null) return value.getValue();
    	return -1; 
    }
    
    /**
     * Returns the Fluorophore used.
     * 
     * @return See above.
     */
    public String getFluor()
    {
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return null;
    	RString value =  lc.getFluor();
    	if (value != null) return value.getValue();
    	return null; 
    }
    
    /**
     * Returns the Pockels cell settings.
     * 
     * @return See above.
     */
    public int getPockelCell()
    {
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return -1;
    	RInt value =  lc.getPockelCellSetting();
    	if (value != null) return value.getValue();
    	return -1; 
    }
    
    /**
     * Returns the illumination.
     * 
     * @return See above.
     */
    public String getIllumination()
    { 
    	if (illumination != null) return illumination.getValue().getValue();
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return null;
    	Illumination value =  lc.getIllumination();
    	if (value != null) return value.getValue().getValue();
    	return null; 
    }

    /**
     * Returns the contrast method.
     * 
     * @return See above.
     */
    public String getContrastMethod()
    { 
    	if (contrastMethod != null) return contrastMethod.getValue().getValue();
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return null;
    	ContrastMethod value =  lc.getContrastMethod();
    	if (value != null) return value.getValue().getValue();
    	return null; 
    }
    
    /**
     * Returns the mode.
     * 
     * @return See above.
     */
    public String getMode()
    { 
    	if (mode != null) return mode.getValue().getValue();
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return null;
    	AcquisitionMode value =  lc.getMode();
    	if (value != null) return value.getValue().getValue();
    	return null; 
    }
    
    /** 
     * Returns the global minimum of the channel i.e. the minimum of all minima.
     * 
     * @return See above.
     */
    public double getGlobalMin()
    { 
    	StatsInfo stats = asChannel().getStatsInfo();
    	if (stats == null) return 0.0;
    	RDouble object = stats.getGlobalMin();
		if (object != null) return object.getValue();
		return 0.0;
    }
    
    /** 
     * Returns the global maximum of the channel i.e. the maximum of all maxima.
     * 
     * @return See above.
     */
    public double getGlobalMax()
    { 
    	StatsInfo stats = asChannel().getStatsInfo();
    	if (stats == null) return 0.0;
    	RDouble object = stats.getGlobalMax();
		if (object != null) return object.getValue();
		return 0.0;
    }
    
    /**
     * Returns <code>true</code> if the channel has some channel information
     * <code>false</code> otherwise.
     * 
     * @return See above.
     */
    public boolean hasStats() { return asChannel().getStatsInfo() != null; }
    
    /**
     * Sets the pinhole size. 
     * 
     * @param value The value to set.
     */
    public void setPinholeSize(double value)
    {
    	if (value < 0) return;
        setDirty(true);
        asChannel().getLogicalChannel().setPinHoleSize(
        		omero.rtypes.rdouble(value));
    }
    
    /**
     * Sets the ND filter.
     * 
     * @param value The value to set.
     */
    public void setNDFilter(double value)
    {
    	if (value < 0) return;
        setDirty(true);
        asChannel().getLogicalChannel().setNdFilter(omero.rtypes.rdouble(value));
    }
    
    /**
     * Sets the fluor.
     * 
     * @param value The value to set.
     */
    public void setFluor(String value)
    {
    	 if (value == null) return;
         setDirty(true);
         asChannel().getLogicalChannel().setFluor(omero.rtypes.rstring(value));
    }
    
    /**
     * Sets the emission wavelength.
     * 
     * @param value The value to set.
     */
    public void setEmissionWavelength(float value)
    {
    	if (value < 0) return;
        setDirty(true);
        asChannel().getLogicalChannel().setEmissionWave(
        		omero.rtypes.rfloat(value));
    }
    
    /**
     * Sets the excitation wavelength.
     * 
     * @param value The value to set.
     */
    public void setExcitationWavelength(float value)
    {
    	if (value < 0) return;
        setDirty(true);
        asChannel().getLogicalChannel().setExcitationWave(
        		omero.rtypes.rfloat(value));
    }
 
    /**
     * Sets the pockel cell.
     * 
     * @param value The value to set.
     */
    public void setPockelCell(int value)
    {
    	if (value < 0) return;
    	LogicalChannel lc = asChannel().getLogicalChannel();
    	if (lc == null) return;
    	setDirty(true);
    	lc.setPockelCellSetting(omero.rtypes.rint(value));
    }
    
    /**
     * Sets the illumination value.
     * 
     * @param illumination The value to set.
     */
    public void setIllumination(Illumination illumination)
    {
    	setDirty(true);
    	this.illumination = illumination;
    }
    
    /**
     * Sets the acquisition mode value.
     * 
     * @param mode The value to set.
     */
    public void setMode(AcquisitionMode mode)
    {
    	setDirty(true);
    	this.mode = mode;
    }
    
    /**
     * Sets the contrast method value.
     * 
     * @param contrastMethod The value to set.
     */
    public void setContrastMethod(ContrastMethod contrastMethod)
    {
    	setDirty(true);
    	this.contrastMethod = contrastMethod;
    }
    
    /**
	 * Returns the acquisition enumeration value.
	 * 
	 * @return See above.
	 */
	public AcquisitionMode getModeAsEnum() { return mode; }
	
	/**
	 * Returns the illumination enumeration value.
	 * 
	 * @return See above.
	 */
	public Illumination getIlluminationAsEnum() { return illumination; }
	
	/**
	 * Returns the contrast method enumeration value.
	 * 
	 * @return See above.
	 */
	public ContrastMethod getContrastMethodAsEnum() { return contrastMethod; }
	
}
