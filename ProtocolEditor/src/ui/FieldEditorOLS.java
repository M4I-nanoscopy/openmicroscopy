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

package ui;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.swing.Icon;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;

import ols.Ontologies;
import ols.OntologyLookUp;

import tree.DataField;
import ui.components.OLSLinkPanel;
import util.BareBonesBrowserLaunch;
import util.ImageFactory;

public class FieldEditorOLS extends FieldEditor {
	
	String ontologyId;
	
	JComboBox parentRelationshipComboBox;
	
	public FieldEditorOLS (DataField dataField) {
		
		super(dataField);
		
		String parentFieldType = dataField.getNode().getParentNode().getDataField().getAttribute(DataField.INPUT_TYPE);
		boolean parentFieldIsOLS = parentFieldType.equals(DataField.OLS_FIELD);
		if (parentFieldIsOLS) {
			JPanel parentRelationshipPanel = new JPanel(new BorderLayout());
			parentRelationshipComboBox = new JComboBox(Ontologies.getOboRelationshipTerms());
			parentRelationshipComboBox.setSelectedItem("PART_OF");
		
			parentRelationshipPanel.add(new JLabel("This is..:"), BorderLayout.WEST);
			parentRelationshipPanel.add(parentRelationshipComboBox, BorderLayout.CENTER);
			parentRelationshipPanel.add(new JLabel("...parent term"), BorderLayout.EAST);
			attributeFieldsPanel.add(parentRelationshipPanel);
		}
		
		// link to the OLS web-site
		attributeFieldsPanel.add(new OLSLinkPanel());
	}
}
