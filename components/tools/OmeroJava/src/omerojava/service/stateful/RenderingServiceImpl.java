/*
 * blitzgateway.service.RenderingServiceImpl 
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
package omerojava.service.stateful;



//Java imports
import java.awt.Color;
import java.awt.image.BufferedImage;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

//Third-party libraries

//Application-internal dependencies

import omero.model.Pixels;
import omerojava.service.gateway.GatewayFactory;
import omerojava.service.gateway.RawFileStoreGateway;
import omerojava.service.gateway.RenderingEngineGateway;

import org.openmicroscopy.shoola.env.data.DSAccessException;
import org.openmicroscopy.shoola.env.data.DSOutOfServiceException;


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
public class RenderingServiceImpl
	implements RenderingService
{	

	/** The gateway factory to create make connection, create and access 
	 *  services .
	 */
	private GatewayFactory 	gatewayFactory;

	/** 
	 * Map of the pixelsId and the gateway, this is used to store the created
	 * renderingEngineGateways. 
	 */
	private Map<Long, RenderingEngineGateway> gatewayMap;
	
	/**
	 * Create the ImageService passing the gateway.
	 * @param gatewayFactory To generate new instances of the 
	 * RenderingEngineGateway.
	 */
	public RenderingServiceImpl(GatewayFactory gatewayFactory) 
	{
		this.gatewayFactory = gatewayFactory;
		gatewayMap = new HashMap<Long, RenderingEngineGateway>();
	}

	/**
	 * Get the gateway for pixels from the map, if it does not exist create it
	 * and add it to the map.
	 * @param pixelsId see above.
	 * @return see above.
	 * @throws DSOutOfServiceException
	 * @throws DSAccessException
	 */
	private RenderingEngineGateway getGateway(Long pixelsId) throws DSOutOfServiceException, DSAccessException
	{
		synchronized(gatewayMap)
		{
			if(gatewayMap.containsKey(pixelsId))
			{
				return gatewayMap.get(pixelsId);
			}
			else
			{
				RenderingEngineGateway gateway = gatewayFactory.getRenderingEngineGateway(pixelsId);
				gatewayMap.put(pixelsId, gateway);
				return gateway;
			}
		}
	}
	
	/**
	 * Does the gateway map contain the gateway for pixelsId.
	 * @param pixelsId see above.
	 * @return see above.
	 */
	public boolean containsGateway(long pixelsId)
	{
		synchronized(gatewayMap)
		{
			return gatewayMap.containsKey(pixelsId);
		}
	}
	
	/**
	 * Close the gateway for pixels = pixelsId
	 * @param pixelsId see above.
	 * @return true if the gateway was closed.
	 * @throws DSOutOfServiceException
	 * @throws DSAccessException
	 */
	public boolean closeGateway(long pixelsId) throws DSOutOfServiceException, DSAccessException
	{
		synchronized(gatewayMap)
		{
			if(containsGateway(pixelsId))
			{
				gatewayMap.remove(pixelsId);
				return true;
			}
			else
				return false;
		}
	}

	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getChannelWindowEnd(java.lang.Long, int)
	 */
	public double getChannelWindowEnd(Long pixelsId, int w)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.getChannelWindowEnd(w);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getChannelWindowStart(java.lang.Long, int)
	 */
	public double getChannelWindowStart(Long pixelsId, int w)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.getChannelWindowStart(w);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getDefaultT(java.lang.Long)
	 */
	public int getDefaultT(Long pixelsId) throws DSOutOfServiceException,
			DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.getDefaultT();
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getDefaultZ(java.lang.Long)
	 */
	public int getDefaultZ(Long pixelsId) throws DSOutOfServiceException,
			DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.getDefaultZ();
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getPixels(java.lang.Long)
	 */
	public Pixels getPixels(Long pixelsId) throws DSOutOfServiceException,
			DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.getPixels();
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#isActive(java.lang.Long, int)
	 */
	public boolean isActive(Long pixelsId, int w)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.isActive(w);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#renderAsPackedInt(java.lang.Long, int, int)
	 */
	public int[] renderAsPackedInt(Long pixelsId, int z, int t)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			return gateway.renderAsPackedInt(z, t);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#setActive(java.lang.Long, int, boolean)
	 */
	public void setActive(Long pixelsId, int w, boolean active)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			gateway.setActive(w, active);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#setChannelWindow(java.lang.Long, int, double, double)
	 */
	public void setChannelWindow(Long pixelsId, int w, double start, double end)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			gateway.setChannelWindow(w, start, end);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#setDefaultT(java.lang.Long, int)
	 */
	public void setDefaultT(Long pixelsId, int t)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			gateway.setDefaultT(t);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#setDefaultZ(java.lang.Long, int)
	 */
	public void setDefaultZ(Long pixelsId, int z)
			throws DSOutOfServiceException, DSAccessException
	{
		RenderingEngineGateway gateway = getGateway(pixelsId);
		synchronized(gateway)
		{
			gateway.setDefaultZ(z);
		}
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getRenderedImage(long, int, int)
	 */
	public BufferedImage getRenderedImage(long pixelsId, int z, int t)
			throws DSOutOfServiceException, DSAccessException
	{
		Pixels pixels = getPixels(pixelsId);
		int[] buff = renderAsPackedInt(pixelsId, z, t);
		return ome.util.ImageUtil.createBufferedImage(buff, pixels.sizeX.val, 
			pixels.sizeY.val);
	}


	/* (non-Javadoc)
	 * @see blitzgateway.service.RenderingService#getRenderedImageMatrix(long, int, int)
	 */
	public int[][][] getRenderedImageMatrix(long pixelsId, int z, int t)
			throws DSOutOfServiceException, DSAccessException
	{
		Pixels pixels = getPixels(pixelsId);
		int width = pixels.sizeX.val;
		int height = pixels.sizeY.val;
		int [][][] data = new int[width][height][3];
		int[] buff = renderAsPackedInt(pixelsId, z, t);
		for(int x = 0 ; x < width ; x++)
			for(int y = 0 ; y < height ; y++)
			{
				int offset = width*y+x;
				Color col = new Color(buff[offset]);
				data[x][y][0] = col.getRed();
				data[x][y][1] = col.getGreen();
				data[x][y][2] = col.getBlue();
			}
		return data;
	}
	
	/* (non-Javadoc)
	 * @see blitzgateway.service.gateway.BaseServiceInterface#keepAlive()
	 */
	public void keepAlive() throws DSOutOfServiceException, DSAccessException
	{
		Iterator<RenderingEngineGateway> gatewayIterator = gatewayMap.values().iterator();
		while(gatewayIterator.hasNext())
		{
			RenderingEngineGateway gateway = gatewayIterator.next();
			gateway.keepAlive();
		}
	}

}


