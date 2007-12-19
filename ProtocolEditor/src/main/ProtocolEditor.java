/*
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
 *	author Will Moore will@lifesci.dundee.ac.uk
 */


package main;

import java.util.ArrayList;
import java.util.List;

import javax.swing.JPanel;

import ols.Observation;
import ols.ObservationCreator;

import ui.XMLView;
import model.XMLModel;

/**
 * This main() class is used to start the application.
 * It is a singleton and its instantiation causes the creation of a single instance of <code>XMLModel</code>.
 * This model class is then passed to a new <code>XMLView</code> class, which builds the whole UI content pane. 
 * 
 * The main() method also calls buildFrame() on the view, which places the content pane in a JFrame.
 * 
 * This buildFrame() method is separated from the model and view instantiation in order that another 
 * application (eg Phenote) can 
 * instantiate this class (and therefore the whole ProtocolEditor) and get the content pane, without
 * building the JFrame.
 * 
 * @author will
 *
 */
public class ProtocolEditor {
	
	/**
	 * singleton uniqueInstance of this class
	 */
	private static ProtocolEditor uniqueInstance;
	/**
	 * the model, which is instantiated by this classes constructor
	 */
	private XMLModel model;
	/**
	 * the view, which is instantiated by this classes constructor, being passed a reference to the model
	 */
	private XMLView view;
	
	/**
	 * The private (and only) constructor for this singleton.
	 */
	private ProtocolEditor() {
		init();
	}
	
	/**
	 * A method used by other applications to get a reference to the uniqueInstance of this class.
	 * Calls the private constructor if the uniqueInstance is null. 
	 * @return	uniqueInstance of this <code>ProtocolEditor</code> class.
	 */
	public static ProtocolEditor getUniqueInstance() {
		
		if (uniqueInstance == null) {
			uniqueInstance = new ProtocolEditor();
		}
		
		return uniqueInstance;
	}
	
	/**
	 * main() method to instantiate this class (includes model and view) and then to buildFrame().
	 * This places the UI main panel in a frame, which is what you want if starting this application
	 * as a stand-alone application.
	 * @param args		not used
	 */
	public static void main(String[] args) {
		
		uniqueInstance = new ProtocolEditor();
		// running this app via main() - need to provide a Frame for UI
		uniqueInstance.buildFrame();
	}

	/**
	 * 
	 */
	public void init() {
		model = new XMLModel();
		view = new XMLView(model);
	}
	
	public void buildFrame() {
		view.buildFrame();
	}
	
	public JPanel getMainPanel() {
		return view.getMainContentPanel();
	}
	
	public List<Observation> getObservations() {
		return ObservationCreator.getObservations(model);
	}
}
