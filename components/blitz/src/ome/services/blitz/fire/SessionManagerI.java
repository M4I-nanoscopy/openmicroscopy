/*
 *   $Id$
 *
 *   Copyright 2007 Glencoe Software, Inc. All rights reserved.
 *   Use is subject to license terms supplied in LICENSE.txt
 */

package ome.services.blitz.fire;

import java.util.List;
import java.util.Map;

import ome.conditions.InternalException;
import ome.logic.HardWiredInterceptor;
import ome.security.SecuritySystem;
import ome.services.blitz.util.ConvertToBlitzExceptionMessage;
import ome.services.blitz.util.CreateSessionMessage;
import ome.system.OmeroContext;
import ome.system.Principal;
import ome.system.Roles;
import ome.util.messages.MessageException;
import omero.constants.EVENT;
import omero.constants.GROUP;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.BeanFactoryUtils;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;

import Glacier2.CannotCreateSessionException;

/**
 * Central login logic for all OMERO.blitz clients. It is required
 * to create a {@link Glacier2.Session} via the {@link Glacier2.SessionManager} 
 * in order to get through the firewall. The {@link Glacier2.Session} (here
 * a {@link ServiceFactoryI} instance) also manages all servants created
 * by the client.
 *
 * @author Josh Moore, josh at glencoesoftware.com
 * @since 3.0-Beta2
 */
public final class SessionManagerI extends Glacier2._SessionManagerDisp
        implements ApplicationContextAware {

    /**
     * "ome.security.basic.BasicSecurityWiring" <em>may</em> be replaced by
     * another value at compile time (see blitz/build.xml), but a default
     * value is necessary here fore testing.
     */
    private final static List<HardWiredInterceptor> CPTORS = HardWiredInterceptor
            .parse(new String[] {"ome.security.basic.BasicSecurityWiring"});

    private final static Log log = LogFactory.getLog(SessionManagerI.class);

    protected OmeroContext context;

    protected SecuritySystem securitySystem;

    public SessionManagerI(SecuritySystem secSys) {
        this.securitySystem = secSys;
    }

    public void setApplicationContext(ApplicationContext applicationContext)
            throws BeansException {
        this.context = (OmeroContext) applicationContext;
        HardWiredInterceptor.configure(CPTORS, context);
    }

    public Glacier2.SessionPrx create(String userId,
            Glacier2.SessionControlPrx control, Ice.Current current)
        throws CannotCreateSessionException {

        Roles roles = securitySystem.getSecurityRoles();

        String group = getGroup(current);
        if (group == null) {
            group = roles.getUserGroupName();
        }
        String event = getEvent(current);
        if (event == null) {
            event = "User"; // FIXME This should be in Roles as well.
        }

        String sessionName = Ice.Util.generateUUID();
        SessionPrincipal principal = new SessionPrincipal(userId, group, event, sessionName);
        Session session = (Session) context.getBean("Session");
        session.setPrincipal(principal);
        session.setInterceptors(CPTORS);

        Ice.Identity id = new Ice.Identity();
        id.category = userId;
        id.name = sessionName;
        Ice.ObjectPrx _prx = current.adapter.add(session,id);
        Glacier2.SessionPrx prx = Glacier2.SessionPrxHelper.uncheckedCast(_prx);

        if (log.isDebugEnabled()) {
            log.debug(String.format("Created session %s for user %s", id.name,
                    userId));
        }

        CreateSessionMessage msg = new CreateSessionMessage(this,id.name,principal);
        try {
            context.publishMessage(msg);
        } catch (CannotCreateSessionException ccse) {
            throw ccse;
        } catch (Throwable t) {
            ConvertToBlitzExceptionMessage convert = new ConvertToBlitzExceptionMessage(this,t);

            try {
                // TODO Possibly provide context.convert(ConversionMsg) methd.
                context.publishMessage(convert);
            } catch (Throwable t2) {
                log.error("Error while converting exception:",t2);
            }

            if (convert.to instanceof CannotCreateSessionException) {
            	throw (CannotCreateSessionException) convert.to;
            }

            // FIXME this copying should be a part of ome.conditions.*
            InternalException ie = new InternalException(t.getMessage());
            ie.setStackTrace(t.getStackTrace());
            throw ie;
        }
        return prx;
    }

    protected String getGroup(Ice.Current current) {
        if (current.ctx == null) return null;
        return current.ctx.get(GROUP.value);
    }

    protected String getEvent(Ice.Current current) {
        if (current.ctx == null) return null;
        return current.ctx.get(EVENT.value);
    }

}
