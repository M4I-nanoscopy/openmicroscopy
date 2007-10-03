/*
 * org.openmicroscopy.shoola.agents.measurement.view.ROIAssistant 
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
package org.openmicroscopy.shoola.agents.measurement.view;


//Java imports
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.ButtonGroup;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.JViewport;

//Third-party libraries

//Application-internal dependencies
import org.openmicroscopy.shoola.agents.measurement.IconManager;
import org.openmicroscopy.shoola.util.roi.model.ROI;
import org.openmicroscopy.shoola.util.roi.model.ROIShape;
import org.openmicroscopy.shoola.util.roi.model.annotation.AnnotationKeys;
import org.openmicroscopy.shoola.util.roi.model.annotation.MeasurementAttributes;
import org.openmicroscopy.shoola.util.roi.model.util.Coord3D;
import org.openmicroscopy.shoola.util.ui.TitlePanel;
import org.openmicroscopy.shoola.util.ui.UIUtilities;

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
class ROIAssistant
	extends JDialog
	implements ActionListener
{	
	
	/** Action command ID to accept the current roi assistant results.*/
	private static final int CLOSE = 0;

	/** 
	 * The table showing the ROI and allowing the user to propagate the selected
	 * ROI through time and Z-section. 
	 */	
	private 	ROIAssistantTable		table;
	
	/**
	 * The model which will define the ROI's displayed in the table.
	 */
	private 	ROIAssistantModel 		model;
	
	/** Text field showing the current type of the selected shape. */
	private 	JTextField				shapeType;
	
	/** Text field showing the x coord of the selected shape. */
	private 	JTextField				xCoord;
	
	/** Text field showing the y coord of the selected shape. */
	private 	JTextField				yCoord;
	
	/** Text field showing the width of the selected shape. */
	private 	JTextField				width;
	
	/** Text field showing the height of the selected shape. */
	private 	JTextField				height;
	
	/** Text field showing the description of the selected shape. */
	private 	JTextField 				description;
	
	/** Checkbox which is selected if the user has selected to add an ROI. */
	private 	JCheckBox 				addButton;
	
	/** Checkbox which is selected if the user has selected to remove an ROI. */
	private 	JCheckBox				removeButton;
		
	/** The scroll pane of the Table. */
	private 	JScrollPane				scrollPane;
	
	/** button closes windows. */
	private 	JButton					closeButton;
	
	/** Model for the measyrement tool. */
	private 	MeasurementViewerUI		view;
		
	/** The initial shape selected when lauching the ROIAssistant. */
	private 	ROIShape 				initialShape;
	
	/**
	 * Maps the coordinate to a cell in the table.
	 * 
	 * @param coord see above.
	 * @return see above.
	 */
	private Point mapCoordToCell(Coord3D coord)
	{
		int w = table.getColumnWidth();
		int x = coord.getTimePoint()*w+table.getLeaderColumnWidth(); 
		int y = coord.getZSection()*w;
		return new Point(x, y);
	}
	
	/** Create the UI for the Assistant. */
	private void buildUI()
	{
		this.setSize(550,530);
		JPanel panel = new JPanel();
		JPanel infoPanel = createInfoPanel();
		JPanel shapePanel = createShapePanel();
		createAcceptButton();
		
		scrollPane = new JScrollPane(table);
		scrollPane.setVerticalScrollBar(scrollPane.createVerticalScrollBar());
		scrollPane.setHorizontalScrollBar(
				scrollPane.createHorizontalScrollBar());
		
		JPanel scrollPanel = new JPanel();
		scrollPanel.setLayout(new BoxLayout(scrollPanel, BoxLayout.X_AXIS));
		scrollPanel.add(Box.createHorizontalStrut(10));
		scrollPanel.add(scrollPane);
		scrollPanel.add(Box.createHorizontalStrut(10));
		scrollPanel.add(createActionPanel());
		scrollPanel.add(Box.createHorizontalStrut(10));
		
		panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
		
		panel.add(infoPanel);
		panel.add(Box.createVerticalStrut(10));
		panel.add(scrollPanel);
		panel.add(Box.createVerticalStrut(10));
		panel.add(shapePanel);
		panel.add(Box.createVerticalStrut(10));
		panel.add(closeButton);
		panel.add(Box.createVerticalStrut(10));
		this.getContentPane().setLayout(new BorderLayout());
		this.getContentPane().add(panel, BorderLayout.CENTER);
	}
	
	/**
	 * Create the table and model.
	 *  
	 * @param numRow The number of z sections in the image. 
	 * @param numCol The numer of time points in the image. 
	 * @param currentPlane the current plane of the image.
	 * @param selectedROI The ROI which will be propagated.
	 */
	private void createTable(int numRow, int numCol, Coord3D currentPlane, 
							ROI selectedROI)
	{
		model = new ROIAssistantModel(numRow, numCol, currentPlane, 
									selectedROI);
		table = new ROIAssistantTable(model);

		table.addMouseListener(new java.awt.event.MouseAdapter() 
		{
			public void mousePressed(java.awt.event.MouseEvent e) 
			{
				int col = table.getSelectedColumn();
				int row = table.getSelectedRow();
				if (col == 0)
					return;
				if(row < 0 || row >= table.getRowCount() || 
							col < 1 || col > table.getColumnCount())
					return;
				Object value = table.getShapeAt(row, col);
				if(value instanceof ROIShape)
				{
					ROIShape shape = (ROIShape)value;
					initialShape = shape;
					shapeType.setText(shape.getFigure().getType());
					description.setText(
							(String) shape.getFigure().getAttribute(
									MeasurementAttributes.TEXT));
					xCoord.setText(shape.getFigure().getStartPoint().getX()+"");
					yCoord.setText(shape.getFigure().getStartPoint().getY()+"");
					width.setText(Math.abs(
							shape.getFigure().getEndPoint().getX()-
							shape.getFigure().getStartPoint().getX())+"");
					height.setText(Math.abs(
							shape.getFigure().getEndPoint().getY()-
							shape.getFigure().getStartPoint().getY())+"");
				}
				else if (value == null)
				{

				}

			}

			public void mouseReleased(java.awt.event.MouseEvent e) 
			{
				if (initialShape == null) return;
				int[] col = table.getSelectedColumns();
				int[] row = table.getSelectedRows();
				for (int i = 0 ; i < row.length ; i++)
					row[i] = (table.getRowCount()-row[i])-1;

				int mincol = col[0];
				int maxcol = col[0];
				int minrow = row[0];
				int maxrow = row[0];

				for (int i = 0 ; i < col.length; i++)
				{
					mincol = Math.min(mincol, col[i]);
					maxcol = Math.max(maxcol, col[i]);
				}
				for (int i = 0 ; i < row.length; i++)
				{
					minrow = Math.min(minrow, row[i]);
					maxrow = Math.max(maxrow, row[i]);
				}
				maxcol = maxcol-1;
				mincol = mincol-1;
				
				if(minrow < 0 || maxrow >= table.getRowCount() || 
						mincol < 0 || maxcol > table.getColumnCount()-1)
					return;
				int boundrow;
				int boundcol;
				if (maxcol != initialShape.getT()) boundcol = maxcol;
				else boundcol = mincol;
				if (maxrow != initialShape.getZ()) boundrow = maxrow;
				else boundrow = minrow;
				
				if (addButton.isSelected())
					view.propagateShape(initialShape, boundcol, boundrow);
				if (removeButton.isSelected())
					view.deleteShape(initialShape, boundcol, boundrow);
				initialShape=null;
				table.repaint();
			}
		});
	}
	
	/**
	 * Creates the action panel is the panel which holds the buttons to choose 
	 * the action to perform on the ROI. 
	 * 
	 * @return See above.
	 */
	private JPanel createActionPanel()
	{
		JPanel actionPanel = new JPanel();
		addButton = new JCheckBox("Add ROI");
		removeButton = new JCheckBox("Remove ROI");
		ButtonGroup group = new ButtonGroup();
		addButton.setSelected(true);
		group.add(addButton);
		group.add(removeButton);
		actionPanel.setLayout(new BorderLayout());
		JPanel subPanel = new JPanel();
		subPanel.setLayout(new BoxLayout(subPanel, BoxLayout.Y_AXIS));
		subPanel.add(addButton);
		subPanel.add(removeButton);
		actionPanel.add(subPanel, BorderLayout.NORTH);
		return actionPanel;
	}
	
	/**
	 * Creates the info panel at the top the the dialog, 
	 * showing a little text about the ROI Assistant. 
	 * 
	 * @return See above.
	 */
	private JPanel createInfoPanel()
	{
		JPanel infoPanel = new TitlePanel("ROI Assistant", 
				"The ROI Assistant allows you to create an ROI " +
				"which extends \n" +
				"through time and z-sections.", 
				IconManager.getInstance().getIcon(IconManager.WIZARD));
		return infoPanel;
	}
	
	/** 
	 * Creates the shape panel which shows the parameters of the initial shape. 
	 * 
	 * @return See above. 
	 */
	private JPanel createShapePanel()
	{
		JPanel shapePanel = new JPanel();
		shapeType = new JTextField();
		description = new JTextField();
		xCoord = new JTextField();
		yCoord = new JTextField();
		width = new JTextField();
		height = new JTextField();
		JLabel shapeTypeLabel = new JLabel("Shape Type ");
		JLabel xCoordLabel = new JLabel("X Coord");
		JLabel yCoordLabel = new JLabel("Y Coord");
		JLabel widthLabel = new JLabel("Width");
		JLabel heightLabel = new JLabel("Height");
		JLabel descriptionLabel = new JLabel("Description");
		JPanel panel = new JPanel();
		panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
		panel.add(createLabelText(shapeTypeLabel, shapeType));
		panel.add(Box.createVerticalStrut(5));
		panel.add(createLabelText(descriptionLabel, description));
		
		JPanel panel2 = new JPanel();
		panel2.setLayout(new BoxLayout(panel2, BoxLayout.Y_AXIS));
		panel2.add(createLabelText(xCoordLabel, xCoord));
		panel2.add(Box.createVerticalStrut(5));
		panel2.add(createLabelText(yCoordLabel, yCoord));
		
		JPanel panel3 = new JPanel();
		panel3.setLayout(new BoxLayout(panel3, BoxLayout.Y_AXIS));
		panel3.add(createLabelText(widthLabel, width));
		panel3.add(Box.createVerticalStrut(5));
		panel3.add(createLabelText(heightLabel, height));
		
		shapePanel.setLayout(new BoxLayout(shapePanel, BoxLayout.X_AXIS));
		shapePanel.add(panel);
		shapePanel.add(Box.createHorizontalStrut(10));
		shapePanel.add(panel2);
		shapePanel.add(Box.createHorizontalStrut(10));
		shapePanel.add(panel3);
		
		return shapePanel;
	}
	
	/** 
	 * Creates a panel with label and textfield.
	 * 
	 * @param l label		The label to layout.
	 * @param t textfield	The field to layout.
	 * @return see above.
	 */
	private JPanel createLabelText(JLabel l, JTextField t)
	{
		JPanel panel = new JPanel();
		panel.setLayout(new BoxLayout(panel, BoxLayout.X_AXIS));
		panel.add(l);
		panel.add(t);
		UIUtilities.setDefaultSize(l, new Dimension(80,22));
		UIUtilities.setDefaultSize(t, new Dimension(80,22));
		return panel;
	}
	
	/** Creates the accept button to close on click. */
	private void createAcceptButton()
	{
		closeButton = new JButton("Close");
		closeButton.setActionCommand(""+CLOSE);
		closeButton.addActionListener(this);
	}

	/** Closes the ROIAssistant window. */
	private void closeAssistant()
	{
		setVisible(false);
		this.dispose();
	}
	
	/**
	 * Creates a new instance.
	 * 
	 * @param numRow		The number of z-sections in the image. 
	 * @param numCol 		The numer of time points in the image. 
	 * @param currentPlane 	The current plane of the image.
	 * @param selectedROI 	The ROI which will be propagated.
	 * @param view a reference to the view. 
	 */
	ROIAssistant(int numRow, int numCol, Coord3D currentPlane, 
						ROI selectedROI, MeasurementViewerUI view)
	{
		super(view);
		this.view = view;
		initialShape = null;
		//this.setAlwaysOnTop(true);
		this.setModal(true);
		createTable(numRow, numCol,currentPlane, selectedROI);
		buildUI();

		JViewport viewPort = scrollPane.getViewport();
		Point point = mapCoordToCell(currentPlane);
		int x = (int) Math.max((point.getX()-6*table.getColumnWidth()), 0);
		int y = (int) Math.max((point.getY()-6*table.getColumnWidth()), 0);
		
		viewPort.setViewPosition(new Point(x, y));
	}

	/**
	 * Reacts to event fired by the various controls.
	 * @see ActionListener#actionPerformed(ActionEvent)
	 */
	public void actionPerformed(ActionEvent evt)
	{
		int id = -1;
		try
		{
			id = Integer.parseInt(evt.getActionCommand());
			switch (id)
			{
				case CLOSE:
					closeAssistant();
					break;
			}
		}
		catch (Exception e)
		{
			// TODO: handle exception
		}
	}

}


