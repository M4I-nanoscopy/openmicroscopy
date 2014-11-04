-- Copyright (C) 2012-4 Glencoe Software, Inc. All rights reserved.
-- Use is subject to license terms supplied in LICENSE.txt
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--

---
--- OMERO5 development release upgrade from OMERO5.0__0 to OMERO5.1DEV__13.
---

BEGIN;

CREATE OR REPLACE FUNCTION omero_assert_db_version(version varchar, patch int) RETURNS void AS '
DECLARE
    rec RECORD;
BEGIN

    SELECT INTO rec *
           FROM dbpatch
          WHERE id = ( SELECT id FROM dbpatch ORDER BY id DESC LIMIT 1 )
            AND currentversion = version
            AND currentpatch = patch;

    IF NOT FOUND THEN
        RAISE EXCEPTION ''ASSERTION ERROR: Wrong database version'';
    END IF;

END;' LANGUAGE plpgsql;

SELECT omero_assert_db_version('OMERO5.0', 0);
DROP FUNCTION omero_assert_db_version(varchar, int);


INSERT INTO dbpatch (currentVersion, currentPatch,   previousVersion,     previousPatch)
             VALUES ('OMERO5.1DEV',  13,             'OMERO5.0',          0);

--
-- Actual upgrade
--

ALTER TABLE session ADD COLUMN userIP varchar(15);
ALTER TABLE logicalchannel ALTER COLUMN emissionWave TYPE FLOAT8;
ALTER TABLE logicalchannel ALTER COLUMN excitationWave TYPE FLOAT8;
ALTER TABLE laser ALTER COLUMN wavelength TYPE FLOAT8;
ALTER TABLE lightsettings ALTER COLUMN wavelength TYPE FLOAT8;

-- #11877 move import logs to upload jobs so they are no longer file annotations
-- may have been missed in 5.0 by users starting from 5.0RC1
CREATE FUNCTION upgrade_import_logs() RETURNS void AS $$

    DECLARE
        import      RECORD;
        time_now    TIMESTAMP WITHOUT TIME ZONE;
        event_type  BIGINT;
        event_id    BIGINT;
        new_link_id BIGINT;

    BEGIN
        SELECT id INTO STRICT event_type FROM eventtype WHERE value = 'Internal';

        FOR import IN
            SELECT fal.id AS old_link_id, a.id AS annotation_id, u.job_id AS job_id, a.file AS log_id
              FROM filesetannotationlink fal, annotation a, filesetjoblink fjl, uploadjob u
             WHERE fal.parent = fjl.parent AND fal.child = a.id AND fjl.child = u.job_id
               AND a.discriminator = '/type/OriginalFile/' AND a.ns = 'openmicroscopy.org/omero/import/logFile' LOOP

            SELECT clock_timestamp() INTO time_now;
            SELECT ome_nextval('seq_event') INTO event_id;
            SELECT ome_nextval('seq_joboriginalfilelink') INTO new_link_id;

            INSERT INTO event (id, permissions, "time", experimenter, experimentergroup, session, type)
                SELECT event_id, a.permissions, time_now, a.owner_id, a.group_id, 0, event_type
                  FROM annotation a WHERE a.id = import.annotation_id;

            INSERT INTO eventlog (id, action, permissions, entityid, entitytype, event)
                SELECT ome_nextval('seq_eventlog'), 'INSERT', e.permissions, new_link_id, 'ome.model.jobs.JobOriginalFileLink', event_id
                  FROM event e WHERE e.id = event_id;

            INSERT INTO joboriginalfilelink (id, permissions, creation_id, update_id, owner_id, group_id, parent, child)
                SELECT new_link_id, old_link.permissions, old_link.creation_id, old_link.update_id, old_link.owner_id, old_link.group_id, import.job_id, import.log_id
                  FROM filesetannotationlink old_link WHERE old_link.id = import.old_link_id;

            UPDATE originalfile SET mimetype = 'application/omero-log-file' WHERE id = import.log_id;

            DELETE FROM annotationannotationlink WHERE parent = import.annotation_id OR child = import.annotation_id;
            DELETE FROM channelannotationlink WHERE child = import.annotation_id;
            DELETE FROM datasetannotationlink WHERE child = import.annotation_id;
            DELETE FROM experimenterannotationlink WHERE child = import.annotation_id;
            DELETE FROM experimentergroupannotationlink WHERE child = import.annotation_id;
            DELETE FROM filesetannotationlink WHERE child = import.annotation_id;
            DELETE FROM imageannotationlink WHERE child = import.annotation_id;
            DELETE FROM namespaceannotationlink WHERE child = import.annotation_id;
            DELETE FROM nodeannotationlink WHERE child = import.annotation_id;
            DELETE FROM originalfileannotationlink WHERE child = import.annotation_id;
            DELETE FROM pixelsannotationlink WHERE child = import.annotation_id;
            DELETE FROM planeinfoannotationlink WHERE child = import.annotation_id;
            DELETE FROM plateacquisitionannotationlink WHERE child = import.annotation_id;
            DELETE FROM plateannotationlink WHERE child = import.annotation_id;
            DELETE FROM projectannotationlink WHERE child = import.annotation_id;
            DELETE FROM reagentannotationlink WHERE child = import.annotation_id;
            DELETE FROM roiannotationlink WHERE child = import.annotation_id;
            DELETE FROM screenannotationlink WHERE child = import.annotation_id;
            DELETE FROM sessionannotationlink WHERE child = import.annotation_id;
            DELETE FROM wellannotationlink WHERE child = import.annotation_id;
            DELETE FROM wellsampleannotationlink WHERE child = import.annotation_id;
            DELETE FROM annotation WHERE id = import.annotation_id;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

SELECT upgrade_import_logs();

DROP FUNCTION upgrade_import_logs();

-- #11664 fix brittleness of _fs_deletelog()
CREATE OR REPLACE FUNCTION _fs_log_delete() RETURNS TRIGGER AS $_fs_log_delete$
    BEGIN
        IF OLD.repo IS NOT NULL THEN
            INSERT INTO _fs_deletelog (event_id, file_id, owner_id, group_id, "path", "name", repo, params)
                SELECT _current_or_new_event(), OLD.id, OLD.owner_id, OLD.group_id, OLD."path", OLD."name", OLD.repo, OLD.params;
        END IF;
        RETURN OLD;
    END;
$_fs_log_delete$ LANGUAGE plpgsql;

-- #11663 SQL DOMAIN types
CREATE DOMAIN nonnegative_int AS INTEGER CHECK (VALUE >= 0);
CREATE DOMAIN positive_int AS INTEGER CHECK (VALUE > 0);
CREATE DOMAIN positive_float AS DOUBLE PRECISION CHECK (VALUE > 0);
CREATE DOMAIN percent_fraction AS DOUBLE PRECISION CHECK (VALUE >= 0 AND VALUE <= 1);

ALTER TABLE detectorsettings ALTER COLUMN integration TYPE positive_int;
ALTER TABLE detectorsettings DROP CONSTRAINT detectorsettings_integration_check;

ALTER TABLE imagingenvironment ALTER COLUMN co2percent TYPE percent_fraction;
ALTER TABLE imagingenvironment ALTER COLUMN humidity TYPE percent_fraction;
ALTER TABLE imagingenvironment DROP CONSTRAINT imagingenvironment_check;

ALTER TABLE laser ALTER COLUMN frequencyMultiplication TYPE positive_int;
ALTER TABLE laser ALTER COLUMN wavelength TYPE positive_float;
ALTER TABLE laser DROP CONSTRAINT laser_check;

ALTER TABLE lightsettings ALTER COLUMN attenuation TYPE percent_fraction;
ALTER TABLE lightsettings ALTER COLUMN wavelength TYPE positive_float;
ALTER TABLE lightsettings DROP CONSTRAINT lightsettings_check;

ALTER TABLE logicalchannel ALTER COLUMN emissionWave TYPE positive_float;
ALTER TABLE logicalchannel ALTER COLUMN excitationWave TYPE positive_float;
ALTER TABLE logicalchannel ALTER COLUMN samplesPerPixel TYPE positive_int;
ALTER TABLE logicalchannel DROP CONSTRAINT logicalchannel_check;

ALTER TABLE otf ALTER COLUMN sizeX TYPE positive_int;
ALTER TABLE otf ALTER COLUMN sizeY TYPE positive_int;
ALTER TABLE otf DROP CONSTRAINT otf_check;

UPDATE pixels SET physicalSizeX = NULL WHERE physicalSizeX <= 0;
UPDATE pixels SET physicalSizeY = NULL WHERE physicalSizeY <= 0;
UPDATE pixels SET physicalSizeZ = NULL WHERE physicalSizeZ <= 0;

ALTER TABLE pixels ALTER COLUMN physicalSizeX TYPE positive_float;
ALTER TABLE pixels ALTER COLUMN physicalSizeY TYPE positive_float;
ALTER TABLE pixels ALTER COLUMN physicalSizeZ TYPE positive_float;
ALTER TABLE pixels ALTER COLUMN significantBits TYPE positive_int;
ALTER TABLE pixels ALTER COLUMN sizeC TYPE positive_int;
ALTER TABLE pixels ALTER COLUMN sizeT TYPE positive_int;
ALTER TABLE pixels ALTER COLUMN sizeX TYPE positive_int;
ALTER TABLE pixels ALTER COLUMN sizeY TYPE positive_int;
ALTER TABLE pixels ALTER COLUMN sizeZ TYPE positive_int;
ALTER TABLE pixels DROP CONSTRAINT pixels_check;

ALTER TABLE planeinfo ALTER COLUMN theC TYPE nonnegative_int;
ALTER TABLE planeinfo ALTER COLUMN theT TYPE nonnegative_int;
ALTER TABLE planeinfo ALTER COLUMN theZ TYPE nonnegative_int;
ALTER TABLE planeinfo DROP CONSTRAINT planeinfo_check;

ALTER TABLE transmittancerange ALTER COLUMN cutIn TYPE positive_int;
ALTER TABLE transmittancerange ALTER COLUMN cutInTolerance TYPE nonnegative_int;
ALTER TABLE transmittancerange ALTER COLUMN cutOut TYPE positive_int;
ALTER TABLE transmittancerange ALTER COLUMN cutOutTolerance TYPE nonnegative_int;
ALTER TABLE transmittancerange ALTER COLUMN transmittance TYPE percent_fraction;
ALTER TABLE transmittancerange DROP CONSTRAINT transmittancerange_check;

-- #12126

UPDATE pixelstype SET bitsize = 16 WHERE value = 'uint16';

-- # map annotation

CREATE TABLE annotation_mapValue (
    annotation_id INT8 NOT NULL,
    mapValue VARCHAR(255) NOT NULL,
    mapValue_key VARCHAR(255),
    PRIMARY KEY (annotation_id, mapValue_key),
    CONSTRAINT FKannotation_mapvalue_map
        FOREIGN KEY (annotation_id) 
        REFERENCES annotation
);

CREATE TABLE experimentergroup_config (
    experimentergroup_id INT8 NOT NULL,
    config VARCHAR(255) NOT NULL,
    config_key VARCHAR(255),
    PRIMARY KEY (experimentergroup_id, config_key),
    CONSTRAINT FKexperimentergroup_config_map
        FOREIGN KEY (experimentergroup_id) 
        REFERENCES experimentergroup
);

CREATE TABLE genericexcitationsource (
    lightsource_id INT8 PRIMARY KEY,
    CONSTRAINT FKgenericexcitationsource_lightsource_id_lightsource 
        FOREIGN KEY (lightsource_id) 
        REFERENCES lightsource
);

CREATE TABLE genericexcitationsource_map (
    genericexcitationsource_id INT8 NOT NULL,
    "map" VARCHAR(255) NOT NULL,
    map_key VARCHAR(255),
    PRIMARY KEY (genericexcitationsource_id, map_key),
    CONSTRAINT FKgenericexcitationsource_map_map
        FOREIGN KEY (genericexcitationsource_id) 
        REFERENCES genericexcitationsource
);

CREATE TABLE imagingenvironment_map (
    imagingenvironment_id INT8 NOT NULL,
    "map" VARCHAR(255) NOT NULL,
    map_key VARCHAR(255),
    PRIMARY KEY (imagingenvironment_id, map_key),
    CONSTRAINT FKimagingenvironment_map_map
        FOREIGN KEY (imagingenvironment_id) 
        REFERENCES imagingenvironment
);

-- #12193: replace FilesetVersionInfo with map property on Fileset

CREATE TABLE metadataimportjob_versioninfo (
    metadataimportjob_id INT8 NOT NULL,
    versioninfo VARCHAR(255) NOT NULL,
    versioninfo_key VARCHAR(255),
    PRIMARY KEY (metadataimportjob_id, versioninfo_key),
    CONSTRAINT FKmetadataimportjob_versioninfo_map
        FOREIGN KEY (metadataimportjob_id) 
        REFERENCES metadataimportjob
);

CREATE TABLE uploadjob_versioninfo (
    uploadjob_id INT8 NOT NULL,
    versioninfo VARCHAR(255) NOT NULL,
    versioninfo_key VARCHAR(255),
    PRIMARY KEY (uploadjob_id, versioninfo_key),
    CONSTRAINT FKuploadjob_versioninfo_map
        FOREIGN KEY (uploadjob_id) 
        REFERENCES uploadjob
);

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'bioformats.reader', filesetversioninfo.bioformatsreader
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'bioformats.version', filesetversioninfo.bioformatsversion
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'locale', filesetversioninfo.locale
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'omero.version', filesetversioninfo.omeroversion
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'os.name', filesetversioninfo.osname
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'os.version', filesetversioninfo.osversion
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO metadataimportjob_versioninfo (metadataimportjob_id, versioninfo_key, versioninfo)
    SELECT metadataimportjob.job_id, 'os.architecture', filesetversioninfo.osarchitecture
    FROM filesetversioninfo, metadataimportjob
    WHERE filesetversioninfo.id = metadataimportjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'bioformats.reader', filesetversioninfo.bioformatsreader
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'bioformats.version', filesetversioninfo.bioformatsversion
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'locale', filesetversioninfo.locale
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'omero.version', filesetversioninfo.omeroversion
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'os.name', filesetversioninfo.osname
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'os.version', filesetversioninfo.osversion
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

INSERT INTO uploadjob_versioninfo (uploadjob_id, versioninfo_key, versioninfo)
    SELECT uploadjob.job_id, 'os.architecture', filesetversioninfo.osarchitecture
    FROM filesetversioninfo, uploadjob
    WHERE filesetversioninfo.id = uploadjob.versioninfo;

ALTER TABLE metadataimportjob DROP COLUMN versioninfo;
ALTER TABLE uploadjob DROP COLUMN versioninfo;

DROP SEQUENCE seq_filesetversioninfo;
DROP TABLE filesetversioninfo;

-- it is not worth keeping these uninformative rows

DELETE FROM metadataimportjob_versioninfo WHERE versioninfo = 'Unknown';
DELETE FROM uploadjob_versioninfo WHERE versioninfo = 'Unknown';

-- #12242: Bug: broken upgrade of nightshade
-- #11479: https://github.com/openmicroscopy/openmicroscopy/pull/2369#issuecomment-41701620
-- So, remove annotations with bad discriminators or inter-group links.

-- return if the group IDs include multiple non-user groups
CREATE FUNCTION is_too_many_group_ids(VARIADIC group_ids BIGINT[]) RETURNS BOOLEAN AS $$

    DECLARE
        user_group  BIGINT;
        other_group BIGINT;
        curr_group  BIGINT;
        index       BIGINT;

    BEGIN
        SELECT id INTO user_group FROM experimentergroup WHERE name = 'user';

        FOR index IN 1 .. array_upper(group_ids, 1) LOOP
            curr_group := group_ids[index];
            CONTINUE WHEN user_group = curr_group;
            IF other_group IS NULL THEN
                other_group := curr_group;
            ELSIF other_group != curr_group THEN
                RETURN TRUE;
            END IF;
        END LOOP;

        RETURN FALSE;
    END;

$$ LANGUAGE plpgsql;

DELETE FROM annotationannotationlink link
      USING annotation parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (parent.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             child.discriminator  IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM channelannotationlink link
      USING channel parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM datasetannotationlink link
      USING dataset parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM experimenterannotationlink link
      USING annotation child
      WHERE link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(link.group_id, child.group_id));

DELETE FROM experimentergroupannotationlink link
      USING annotation child
      WHERE link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(link.group_id, child.group_id));

DELETE FROM filesetannotationlink link
      USING fileset parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM imageannotationlink link
      USING image parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM namespaceannotationlink link
      USING namespace parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM nodeannotationlink link
      USING annotation child
      WHERE link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(link.group_id, child.group_id));

DELETE FROM originalfileannotationlink link
      USING originalfile parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM pixelsannotationlink link
      USING pixels parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM planeinfoannotationlink link
      USING planeinfo parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM plateacquisitionannotationlink link
      USING plateacquisition parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM plateannotationlink link
      USING plate parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM projectannotationlink link
      USING project parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM reagentannotationlink link
      USING reagent parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM roiannotationlink link
      USING roi parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM screenannotationlink link
      USING screen parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM sessionannotationlink link
      USING annotation child
      WHERE link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(link.group_id, child.group_id));

DELETE FROM wellannotationlink link
      USING well parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DELETE FROM wellsampleannotationlink link
      USING wellsample parent, annotation child
      WHERE link.parent = parent.id AND link.child = child.id
        AND (child.discriminator IN ('/basic/text/uri/', '/basic/text/url/') OR
             is_too_many_group_ids(parent.group_id, link.group_id, child.group_id));

DROP FUNCTION is_too_many_group_ids(VARIADIC group_ids BIGINT[]);

DELETE FROM annotation
      WHERE discriminator IN ('/basic/text/uri/', '/basic/text/url/');


-- Remove all DB checks

DELETE FROM configuration
      WHERE name LIKE ('DB check %');


-- Annotation link triggers for search
-- Note: no annotation insert trigger

DROP TRIGGER IF EXISTS annotation_annotation_link_event_trigger_insert ON annotationannotationlink;

CREATE TRIGGER annotation_annotation_link_event_trigger_insert
        AFTER INSERT ON annotationannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.annotations.Annotation');

DROP TRIGGER IF EXISTS channel_annotation_link_event_trigger_insert ON channelannotationlink;

CREATE TRIGGER channel_annotation_link_event_trigger_insert
        AFTER INSERT ON channelannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.core.Channel');

DROP TRIGGER IF EXISTS dataset_annotation_link_event_trigger_insert ON datasetannotationlink;

CREATE TRIGGER dataset_annotation_link_event_trigger_insert
        AFTER INSERT ON datasetannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.containers.Dataset');

DROP TRIGGER IF EXISTS experimenter_annotation_link_event_trigger_insert ON experimenterannotationlink;

CREATE TRIGGER experimenter_annotation_link_event_trigger_insert
        AFTER INSERT ON experimenterannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.meta.Experimenter');

DROP TRIGGER IF EXISTS experimentergroup_annotation_link_event_trigger_insert ON experimentergroupannotationlink;

CREATE TRIGGER experimentergroup_annotation_link_event_trigger_insert
        AFTER INSERT ON experimentergroupannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.meta.ExperimenterGroup');

DROP TRIGGER IF EXISTS fileset_annotation_link_event_trigger_insert ON filesetannotationlink;

CREATE TRIGGER fileset_annotation_link_event_trigger_insert
        AFTER INSERT ON filesetannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.fs.Fileset');

DROP TRIGGER IF EXISTS image_annotation_link_event_trigger_insert ON imageannotationlink;

CREATE TRIGGER image_annotation_link_event_trigger_insert
        AFTER INSERT ON imageannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.core.Image');

DROP TRIGGER IF EXISTS namespace_annotation_link_event_trigger_insert ON namespaceannotationlink;

CREATE TRIGGER namespace_annotation_link_event_trigger_insert
        AFTER INSERT ON namespaceannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.meta.Namespace');

DROP TRIGGER IF EXISTS node_annotation_link_event_trigger_insert ON nodeannotationlink;

CREATE TRIGGER node_annotation_link_event_trigger_insert
        AFTER INSERT ON nodeannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.meta.Node');

DROP TRIGGER IF EXISTS originalfile_annotation_link_event_trigger_insert ON originalfileannotationlink;

CREATE TRIGGER originalfile_annotation_link_event_trigger_insert
        AFTER INSERT ON originalfileannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.core.OriginalFile');

DROP TRIGGER IF EXISTS pixels_annotation_link_event_trigger_insert ON pixelsannotationlink;

CREATE TRIGGER pixels_annotation_link_event_trigger_insert
        AFTER INSERT ON pixelsannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.core.Pixels');

DROP TRIGGER IF EXISTS planeinfo_annotation_link_event_trigger_insert ON planeinfoannotationlink;

CREATE TRIGGER planeinfo_annotation_link_event_trigger_insert
        AFTER INSERT ON planeinfoannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.core.PlaneInfo');

DROP TRIGGER IF EXISTS plate_annotation_link_event_trigger_insert ON plateannotationlink;

CREATE TRIGGER plate_annotation_link_event_trigger_insert
        AFTER INSERT ON plateannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.Plate');

DROP TRIGGER IF EXISTS plateacquisition_annotation_link_event_trigger_insert ON plateacquisitionannotationlink;

CREATE TRIGGER plateacquisition_annotation_link_event_trigger_insert
        AFTER INSERT ON plateacquisitionannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.PlateAcquisition');

DROP TRIGGER IF EXISTS project_annotation_link_event_trigger_insert ON projectannotationlink;

CREATE TRIGGER project_annotation_link_event_trigger_insert
        AFTER INSERT ON projectannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.containers.Project');

DROP TRIGGER IF EXISTS reagent_annotation_link_event_trigger_insert ON reagentannotationlink;

CREATE TRIGGER reagent_annotation_link_event_trigger_insert
        AFTER INSERT ON reagentannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.Reagent');

DROP TRIGGER IF EXISTS roi_annotation_link_event_trigger_insert ON roiannotationlink;

CREATE TRIGGER roi_annotation_link_event_trigger_insert
        AFTER INSERT ON roiannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.roi.Roi');

DROP TRIGGER IF EXISTS screen_annotation_link_event_trigger_insert ON screenannotationlink;

CREATE TRIGGER screen_annotation_link_event_trigger_insert
        AFTER INSERT ON screenannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.Screen');

DROP TRIGGER IF EXISTS session_annotation_link_event_trigger_insert ON sessionannotationlink;

CREATE TRIGGER session_annotation_link_event_trigger_insert
        AFTER INSERT ON sessionannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.meta.Session');

DROP TRIGGER IF EXISTS well_annotation_link_event_trigger_insert ON wellannotationlink;

CREATE TRIGGER well_annotation_link_event_trigger_insert
        AFTER INSERT ON wellannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.Well');

DROP TRIGGER IF EXISTS wellsample_annotation_link_event_trigger_insert ON wellsampleannotationlink;

CREATE TRIGGER wellsample_annotation_link_event_trigger_insert
        AFTER INSERT ON wellsampleannotationlink
        FOR EACH ROW
        EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.screen.WellSample');

-- Add new checksum algorithm to enumeration.

INSERT INTO checksumalgorithm (id, permissions, value) 
    SELECT ome_nextval('seq_checksumalgorithm'), -52, 'File-Size-64'
    WHERE NOT EXISTS (SELECT id FROM checksumalgorithm WHERE value = 'File-Size-64');

-- Reverse endianness of hashes calculated with adjusted algorithms.

CREATE FUNCTION reverse_endian(forward TEXT) RETURNS TEXT AS $$

DECLARE
    index INTEGER := length(forward) - 1;
    backward TEXT := '';

BEGIN
    WHILE index > 0 LOOP
        backward := backward || substring(forward FROM index FOR 2);
        index := index - 2;
    END LOOP;
    IF index = 0 THEN
        RAISE 'cannot reverse strings of odd length';
    END IF;
    RETURN backward;
END;
$$ LANGUAGE plpgsql;

UPDATE originalfile SET hash = reverse_endian(hash)
    WHERE hash IS NOT NULL AND hasher IN
    (SELECT id FROM checksumalgorithm WHERE value IN ('Adler-32', 'CRC-32'));

DROP FUNCTION reverse_endian(TEXT);

-- Acquisition date is already optional in XML schema.

ALTER TABLE image ALTER COLUMN acquisitiondate DROP NOT NULL;

-- Trac ticket #970

ALTER TABLE dbpatch DROP CONSTRAINT unique_dbpatch;
ALTER TABLE dbpatch ADD CONSTRAINT unique_dbpatch
  UNIQUE (currentversion, currentpatch, previousversion, previouspatch, message);

-- Trac ticket #12317 -- delete map property values along with their holders

CREATE FUNCTION experimentergroup_config_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM experimentergroup_config
        WHERE experimentergroup_id = OLD.id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;

CREATE TRIGGER experimentergroup_config_map_entry_delete_trigger
    BEFORE DELETE ON experimentergroup
    FOR EACH ROW
    EXECUTE PROCEDURE experimentergroup_config_map_entry_delete_trigger_function();

CREATE FUNCTION genericexcitationsource_map_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM genericexcitationsource_map
        WHERE genericexcitationsource_id = OLD.lightsource_id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;
 
CREATE TRIGGER genericexcitationsource_map_map_entry_delete_trigger
    BEFORE DELETE ON genericexcitationsource
    FOR EACH ROW
    EXECUTE PROCEDURE genericexcitationsource_map_map_entry_delete_trigger_function();

CREATE FUNCTION imagingenvironment_map_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM imagingenvironment_map
        WHERE imagingenvironment_id = OLD.id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;

CREATE TRIGGER imagingenvironment_map_map_entry_delete_trigger
    BEFORE DELETE ON imagingenvironment
    FOR EACH ROW
    EXECUTE PROCEDURE imagingenvironment_map_map_entry_delete_trigger_function();

CREATE FUNCTION annotation_mapValue_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM annotation_mapValue
        WHERE annotation_id = OLD.id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;

CREATE TRIGGER annotation_mapValue_map_entry_delete_trigger
    BEFORE DELETE ON annotation
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_mapValue_map_entry_delete_trigger_function();

CREATE FUNCTION metadataimportjob_versionInfo_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM metadataimportjob_versionInfo
        WHERE metadataimportjob_id = OLD.job_id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;

CREATE TRIGGER metadataimportjob_versionInfo_map_entry_delete_trigger
    BEFORE DELETE ON metadataimportjob
    FOR EACH ROW
    EXECUTE PROCEDURE metadataimportjob_versionInfo_map_entry_delete_trigger_function();

CREATE FUNCTION uploadjob_versionInfo_map_entry_delete_trigger_function() RETURNS "trigger" AS '
BEGIN
    DELETE FROM uploadjob_versionInfo
        WHERE uploadjob_id = OLD.job_id;
    RETURN OLD;
END;'
LANGUAGE plpgsql;

CREATE TRIGGER uploadjob_versionInfo_map_entry_delete_trigger
    BEFORE DELETE ON uploadjob
    FOR EACH ROW
    EXECUTE PROCEDURE uploadjob_versionInfo_map_entry_delete_trigger_function();


-- Adding extra annotation points to the model

CREATE TABLE detectorannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKdetectorannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKdetectorannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKdetectorannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKdetectorannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKdetectorannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKdetectorannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKdetectorannotationlink_parent_detector FOREIGN KEY (parent) REFERENCES detector
);

CREATE INDEX i_detectorannotationlink_owner ON detectorannotationlink(owner_id);
CREATE INDEX i_detectorannotationlink_group ON detectorannotationlink(group_id);
CREATE INDEX i_DetectorAnnotationLink_parent ON detectorannotationlink(parent);
CREATE INDEX i_DetectorAnnotationLink_child ON detectorannotationlink(child);

CREATE TRIGGER detector_annotation_link_event_trigger
    AFTER UPDATE ON detectorannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Detector');

CREATE TRIGGER detector_annotation_link_delete_trigger
    BEFORE DELETE ON detectorannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.Detector');

CREATE SEQUENCE seq_detectorannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_detectorannotationlink', nextval('_lock_seq');

CREATE VIEW count_detector_annotationlinks_by_owner (detector_id, owner_id, count) 
    AS SELECT parent, owner_id, count(*)
    FROM detectorannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE dichroicannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKdichroicannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKdichroicannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKdichroicannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKdichroicannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKdichroicannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKdichroicannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKdichroicannotationlink_parent_dichroic FOREIGN KEY (parent) REFERENCES dichroic
);

CREATE INDEX i_dichroicannotationlink_owner ON dichroicannotationlink(owner_id);
CREATE INDEX i_dichroicannotationlink_group ON dichroicannotationlink(group_id);
CREATE INDEX i_DichroicAnnotationLink_parent ON dichroicannotationlink(parent);
CREATE INDEX i_DichroicAnnotationLink_child ON dichroicannotationlink(child);

CREATE TRIGGER dichroic_annotation_link_event_trigger
    AFTER UPDATE ON dichroicannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Dichroic');

CREATE TRIGGER dichroic_annotation_link_delete_trigger
    BEFORE DELETE ON dichroicannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.Dichroic');

CREATE SEQUENCE seq_dichroicannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_dichroicannotationlink', nextval('_lock_seq');

CREATE VIEW count_dichroic_annotationlinks_by_owner (dichroic_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM dichroicannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE filterannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKfilterannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKfilterannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKfilterannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKfilterannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKfilterannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKfilterannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKfilterannotationlink_parent_filter FOREIGN KEY (parent) REFERENCES filter
);

CREATE INDEX i_filterannotationlink_owner ON filterannotationlink(owner_id);
CREATE INDEX i_filterannotationlink_group ON filterannotationlink(group_id);
CREATE INDEX i_FilterAnnotationLink_parent ON filterannotationlink(parent);
CREATE INDEX i_FilterAnnotationLink_child ON filterannotationlink(child);

CREATE TRIGGER filter_annotation_link_event_trigger
    AFTER UPDATE ON filterannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Filter');

CREATE TRIGGER filter_annotation_link_delete_trigger
    BEFORE DELETE ON filterannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.Filter');

CREATE SEQUENCE seq_filterannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_filterannotationlink', nextval('_lock_seq');

CREATE VIEW count_filter_annotationlinks_by_owner (filter_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM filterannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE instrumentannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKinstrumentannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKinstrumentannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKinstrumentannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKinstrumentannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKinstrumentannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKinstrumentannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKinstrumentannotationlink_parent_instrument FOREIGN KEY (parent) REFERENCES instrument
);

CREATE INDEX i_instrumentannotationlink_owner ON instrumentannotationlink(owner_id);
CREATE INDEX i_instrumentannotationlink_group ON instrumentannotationlink(group_id);
CREATE INDEX i_InstrumentAnnotationLink_parent ON instrumentannotationlink(parent);
CREATE INDEX i_InstrumentAnnotationLink_child ON instrumentannotationlink(child);

CREATE TRIGGER instrument_annotation_link_event_trigger
    AFTER UPDATE ON instrumentannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Instrument');

CREATE TRIGGER instrument_annotation_link_delete_trigger
    BEFORE DELETE ON instrumentannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.Instrument');

CREATE SEQUENCE seq_instrumentannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_instrumentannotationlink', nextval('_lock_seq');

CREATE VIEW count_instrument_annotationlinks_by_owner (instrument_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM instrumentannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE lightpathannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKlightpathannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKlightpathannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKlightpathannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKlightpathannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKlightpathannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKlightpathannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKlightpathannotationlink_parent_lightpath FOREIGN KEY (parent) REFERENCES lightpath
);

CREATE INDEX i_lightpathannotationlink_owner ON lightpathannotationlink(owner_id);
CREATE INDEX i_lightpathannotationlink_group ON lightpathannotationlink(group_id);
CREATE INDEX i_LightPathAnnotationLink_parent ON lightpathannotationlink(parent);
CREATE INDEX i_LightPathAnnotationLink_child ON lightpathannotationlink(child);

CREATE TRIGGER lightpath_annotation_link_event_trigger
    AFTER UPDATE ON lightpathannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.LightPath');

CREATE TRIGGER lightpath_annotation_link_delete_trigger
    BEFORE DELETE ON lightpathannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.LightPath');

CREATE SEQUENCE seq_lightpathannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_lightpathannotationlink', nextval('_lock_seq');

CREATE VIEW count_lightpath_annotationlinks_by_owner (lightpath_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM lightpathannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE lightsourceannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKlightsourceannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKlightsourceannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKlightsourceannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKlightsourceannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKlightsourceannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKlightsourceannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKlightsourceannotationlink_parent_lightsource FOREIGN KEY (parent) REFERENCES lightsource
);

CREATE INDEX i_lightsourceannotationlink_owner ON lightsourceannotationlink(owner_id);
CREATE INDEX i_lightsourceannotationlink_group ON lightsourceannotationlink(group_id);
CREATE INDEX i_LightSourceAnnotationLink_parent ON lightsourceannotationlink(parent);
CREATE INDEX i_LightSourceAnnotationLink_child ON lightsourceannotationlink(child);

CREATE TRIGGER lightsource_annotation_link_event_trigger
    AFTER UPDATE ON lightsourceannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.LightSource');

CREATE TRIGGER lightsource_annotation_link_delete_trigger
    BEFORE DELETE ON lightsourceannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.LightSource');

CREATE SEQUENCE seq_lightsourceannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_lightsourceannotationlink', nextval('_lock_seq');

CREATE VIEW count_lightsource_annotationlinks_by_owner (lightsource_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM lightsourceannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE objectiveannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKobjectiveannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKobjectiveannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKobjectiveannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKobjectiveannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKobjectiveannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKobjectiveannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKobjectiveannotationlink_parent_objective FOREIGN KEY (parent) REFERENCES objective
);

CREATE INDEX i_objectiveannotationlink_owner ON objectiveannotationlink(owner_id);
CREATE INDEX i_objectiveannotationlink_group ON objectiveannotationlink(group_id);
CREATE INDEX i_ObjectiveAnnotationLink_parent ON objectiveannotationlink(parent);
CREATE INDEX i_ObjectiveAnnotationLink_child ON objectiveannotationlink(child);

CREATE TRIGGER objective_annotation_link_event_trigger
    AFTER UPDATE ON objectiveannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Objective');

CREATE TRIGGER objective_annotation_link_delete_trigger
    BEFORE DELETE ON objectiveannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.acquisition.Objective');

CREATE SEQUENCE seq_objectiveannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_objectiveannotationlink', nextval('_lock_seq');

CREATE VIEW count_objective_annotationlinks_by_owner (objective_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM objectiveannotationlink GROUP BY parent, owner_id ORDER BY parent;

CREATE TABLE shapeannotationlink (
    id INT8 PRIMARY KEY,
    permissions INT8 NOT NULL,
    version INT4,
    child INT8 NOT NULL,
    creation_id INT8 NOT NULL,
    external_id INT8 UNIQUE,
    group_id INT8 NOT NULL,
    owner_id INT8 NOT NULL,
    update_id INT8 NOT NULL,
    parent INT8 NOT NULL,
    UNIQUE (parent, child, owner_id),
    CONSTRAINT FKshapeannotationlink_creation_id_event FOREIGN KEY (creation_id) REFERENCES event,
    CONSTRAINT FKshapeannotationlink_child_annotation FOREIGN KEY (child) REFERENCES annotation,
    CONSTRAINT FKshapeannotationlink_update_id_event FOREIGN KEY (update_id) REFERENCES event,
    CONSTRAINT FKshapeannotationlink_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo,
    CONSTRAINT FKshapeannotationlink_group_id_experimentergroup FOREIGN KEY (group_id) REFERENCES experimentergroup,
    CONSTRAINT FKshapeannotationlink_owner_id_experimenter FOREIGN KEY (owner_id) REFERENCES experimenter,
    CONSTRAINT FKshapeannotationlink_parent_shape FOREIGN KEY (parent) REFERENCES shape
);

CREATE INDEX i_shapeannotationlink_owner ON shapeannotationlink(owner_id);
CREATE INDEX i_shapeannotationlink_group ON shapeannotationlink(group_id);
CREATE INDEX i_ShapeAnnotationLink_parent ON shapeannotationlink(parent);
CREATE INDEX i_ShapeAnnotationLink_child ON shapeannotationlink(child);

CREATE TRIGGER shape_annotation_link_event_trigger
    AFTER UPDATE ON shapeannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.roi.Shape');

CREATE TRIGGER shape_annotation_link_delete_trigger
    BEFORE DELETE ON shapeannotationlink
    FOR EACH ROW
    EXECUTE PROCEDURE annotation_link_delete_trigger('ome.model.roi.Shape');

CREATE SEQUENCE seq_shapeannotationlink;
INSERT INTO _lock_ids (name, id) SELECT 'seq_shapeannotationlink', nextval('_lock_seq');

CREATE VIEW count_shape_annotationlinks_by_owner (shape_id, owner_id, count)
    AS SELECT parent, owner_id, count(*)
    FROM shapeannotationlink GROUP BY parent, owner_id ORDER BY parent;

INSERT INTO imageannotationlink (id, permissions, version, child, creation_id, external_id, group_id, owner_id, update_id, parent)
    SELECT ome_nextval('seq_imageannotationlink'), pal.permissions, pal.version, pal.child, pal.creation_id, pal.external_id, pal.group_id, pal.owner_id, pal.update_id, pixels.image
    FROM pixelsannotationlink pal, pixels
    WHERE pal.parent = pixels.id;

DROP VIEW count_Pixels_annotationLinks_by_owner;
DROP SEQUENCE seq_pixelsannotationlink;
DROP TABLE pixelsannotationlink;

INSERT INTO imageannotationlink (id, permissions, version, child, creation_id, external_id, group_id, owner_id, update_id, parent)
    SELECT ome_nextval('seq_imageannotationlink'), wsl.permissions, wsl.version, wsl.child, wsl.creation_id, wsl.external_id, wsl.group_id, wsl.owner_id, wsl.update_id, wellsample.image
    FROM wellsampleannotationlink wsl, wellsample
    WHERE wsl.parent = wellsample.id;

DROP VIEW count_WellSample_annotationLinks_by_owner;
DROP SEQUENCE seq_wellsampleannotationlink;
DROP TABLE wellsampleannotationlink;

DELETE FROM _lock_ids WHERE 'name' IN ('seq_pixelsannotationlink',
                                       'seq_wellsampleannotationlink');

CREATE OR REPLACE FUNCTION annotation_update_event_trigger() RETURNS "trigger"
    AS '
    DECLARE
        rec RECORD;
        eid INT8;
        cnt INT8;
    BEGIN

        IF NOT EXISTS(SELECT table_name FROM information_schema.tables where table_name = ''_updated_annotations'') THEN
            CREATE TEMP TABLE _updated_annotations (entitytype varchar, entityid INT8) ON COMMIT DELETE ROWS;
        END IF;


        FOR rec IN SELECT id, parent FROM annotationannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.annotations.Annotation'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM channelannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.core.Channel'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM datasetannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.containers.Dataset'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM detectorannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.Detector'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM dichroicannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.Dichroic'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM experimenterannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.meta.Experimenter'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM experimentergroupannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.meta.ExperimenterGroup'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM filesetannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.fs.Fileset'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM filterannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.Filter'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM imageannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.core.Image'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM instrumentannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.Instrument'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM lightpathannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.LightPath'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM lightsourceannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.LightSource'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM namespaceannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.meta.Namespace'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM nodeannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.meta.Node'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM objectiveannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.acquisition.Objective'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM originalfileannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.core.OriginalFile'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM planeinfoannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.core.PlaneInfo'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM plateannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.screen.Plate'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM plateacquisitionannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.screen.PlateAcquisition'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM projectannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.containers.Project'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM reagentannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.screen.Reagent'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM roiannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.roi.Roi'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM screenannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.screen.Screen'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM sessionannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.meta.Session'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM shapeannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.roi.Shape'');
        END LOOP;

        FOR rec IN SELECT id, parent FROM wellannotationlink WHERE child = new.id LOOP
            INSERT INTO _updated_annotations (entityid, entitytype) values (rec.parent, ''ome.model.screen.Well'');
        END LOOP;

        SELECT INTO cnt count(*) FROM _updated_annotations;
        IF cnt <> 0 THEN
            SELECT INTO eid _current_or_new_event();
            INSERT INTO eventlog (id, action, permissions, entityid, entitytype, event)
                 SELECT ome_nextval(''seq_eventlog''), ''REINDEX'', -52, entityid, entitytype, eid
                   FROM _updated_annotations;
        END IF;

        RETURN new;

    END;'
LANGUAGE plpgsql;

-- #970 adjust constraint for dbpatch versions/patches

ALTER TABLE dbpatch DROP CONSTRAINT unique_dbpatch;

CREATE FUNCTION dbpatch_versions_trigger_function() RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.currentversion <> NEW.previousversion OR NEW.currentpatch <> NEW.previouspatch) AND
       (SELECT COUNT(*) FROM dbpatch WHERE id <> NEW.id AND
        (currentversion <> previousversion OR currentpatch <> previouspatch) AND
        ((currentversion = NEW.currentversion AND currentpatch = NEW.currentpatch) OR
         (previousversion = NEW.previousversion AND previouspatch = NEW.previouspatch))) > 0 THEN
        RAISE 'upgrades cannot be repeated';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER dbpatch_versions_trigger
    BEFORE INSERT OR UPDATE ON dbpatch
    FOR EACH ROW
    EXECUTE PROCEDURE dbpatch_versions_trigger_function();

-- expand password hash and note password change dates

ALTER TABLE password ALTER COLUMN hash TYPE VARCHAR(255);
ALTER TABLE password ADD COLUMN changed TIMESTAMP WITHOUT TIME ZONE;

-- fill in password change dates from event log

CREATE FUNCTION update_changed_from_event_log() RETURNS void AS $$

DECLARE
    exp_id BIGINT;
    time_changed TIMESTAMP WITHOUT TIME ZONE;

BEGIN
    FOR exp_id IN
        SELECT DISTINCT ev.experimenter 
            FROM event ev, eventlog log, experimenter ex
            WHERE log.action = 'PASSWORD' AND ex.omename <> 'root'
            AND ev.id = log.event AND ev.experimenter = ex.id LOOP

        SELECT ev.time
            INTO STRICT time_changed
            FROM event ev, eventlog log
            WHERE log.action = 'PASSWORD' AND ev.experimenter = exp_id
            AND ev.id = log.event
            ORDER BY log.id DESC LIMIT 1;
       
        UPDATE password SET changed = time_changed
            WHERE experimenter_id = exp_id;
    END LOOP;

END;
$$ LANGUAGE plpgsql;

SELECT update_changed_from_event_log();

DROP FUNCTION update_changed_from_event_log();

-- 5.1DEV__11: time units

CREATE SEQUENCE seq_unitstime
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE TABLE unitstime (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

ALTER TABLE pixels
	ADD COLUMN timeincrementunit bigint;

ALTER TABLE planeinfo
	ADD COLUMN deltatunit bigint,
	ADD COLUMN exposuretimeunit bigint;

ALTER TABLE unitstime
	ADD CONSTRAINT unitstime_pkey PRIMARY KEY (id);

ALTER TABLE pixels
	ADD CONSTRAINT fkpixels_timeincrementunit_unitstime FOREIGN KEY (timeincrementunit) REFERENCES unitstime(id);

ALTER TABLE planeinfo
	ADD CONSTRAINT fkplaneinfo_deltaunit_unitstime FOREIGN KEY (deltatunit) REFERENCES unitstime(id);

ALTER TABLE planeinfo
	ADD CONSTRAINT fkplaneinfo_exposuretimeunit_unitstime FOREIGN KEY (exposuretimeunit) REFERENCES unitstime(id);

ALTER TABLE unitstime
	ADD CONSTRAINT unitstime_external_id_key UNIQUE (external_id);

ALTER TABLE unitstime
	ADD CONSTRAINT unitstime_value_key UNIQUE (value);

ALTER TABLE unitstime
	ADD CONSTRAINT fkunitstime_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

CREATE INDEX i_pixels_timeincrement ON pixels USING btree (timeincrement);

CREATE INDEX i_planeinfo_deltat ON planeinfo USING btree (deltat);

CREATE INDEX i_planeinfo_exposuretime ON planeinfo USING btree (exposuretime);

-- 5.1DEV__11: Manual adjustments, mostly from psql-footer.sql

insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Ys','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Zs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Es','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Ps','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Ts','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Gs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'Ms','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ks','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'hs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'das','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'s','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ds','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'cs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ms','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'µs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ns','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ps','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'fs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'as','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'zs','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'ys','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'min','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'h','SI.SECOND';
insert into unitstime (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstime'),-52,'d','SI.SECOND';

update pixels set timeincrementunit = (select id from unitstime where value = 's') where timeincrement is not null;
update planeinfo set deltatunit = (select id from unitstime where value = 's')  where deltat is not null;
update planeinfo set exposuretimeunit = (select id from unitstime where value = 's') where exposuretime is not null;

-- 5.1DEV__13: other units

CREATE SEQUENCE seq_unitselectricpotential
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE seq_unitsfrequency
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE seq_unitslength
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE seq_unitspower
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE seq_unitspressure
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE seq_unitstemperature
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE TABLE unitselectricpotential (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

CREATE TABLE unitsfrequency (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

CREATE TABLE unitslength (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

CREATE TABLE unitspower (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255),
	"value" character varying(255) NOT NULL,
	external_id bigint
);

CREATE TABLE unitspressure (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

CREATE TABLE unitstemperature (
	id bigint NOT NULL,
	permissions bigint NOT NULL,
	measurementsystem character varying(255) NOT NULL,
	"value" character varying(255) NOT NULL,
	external_id bigint
);

ALTER TABLE detector
	ADD COLUMN voltageunit bigint;

ALTER TABLE detectorsettings
	ADD COLUMN readoutrateunit bigint,
	ADD COLUMN voltageunit bigint;

ALTER TABLE imagingenvironment
	ADD COLUMN airpressureunit bigint,
	ADD COLUMN temperatureunit bigint;

ALTER TABLE laser
	ADD COLUMN repetitionrateunit bigint,
	ADD COLUMN wavelengthunit bigint,
	ALTER COLUMN wavelength TYPE double precision /* TYPE change - table: laser original: positive_float new: double precision */;

ALTER TABLE lightsettings
	ADD COLUMN wavelengthunit bigint,
	ALTER COLUMN wavelength TYPE double precision /* TYPE change - table: lightsettings original: positive_float new: double precision */;

ALTER TABLE lightsource
	ADD COLUMN powerunit bigint;

ALTER TABLE logicalchannel
	ADD COLUMN emissionwaveunit bigint,
	ADD COLUMN excitationwaveunit bigint,
	ADD COLUMN pinholesizeunit bigint,
	ALTER COLUMN emissionwave TYPE double precision /* TYPE change - table: logicalchannel original: positive_float new: double precision */,
	ALTER COLUMN excitationwave TYPE double precision /* TYPE change - table: logicalchannel original: positive_float new: double precision */;

ALTER TABLE objective
	ADD COLUMN workingdistanceunit bigint;

ALTER TABLE pixels
	ADD COLUMN physicalsizexunit bigint,
	ADD COLUMN physicalsizeyunit bigint,
	ADD COLUMN physicalsizezunit bigint,
	ALTER COLUMN physicalsizex TYPE double precision /* TYPE change - table: pixels original: positive_float new: double precision */,
	ALTER COLUMN physicalsizey TYPE double precision /* TYPE change - table: pixels original: positive_float new: double precision */,
	ALTER COLUMN physicalsizez TYPE double precision /* TYPE change - table: pixels original: positive_float new: double precision */;

ALTER TABLE planeinfo
	ADD COLUMN positionxunit bigint,
	ADD COLUMN positionyunit bigint,
	ADD COLUMN positionzunit bigint;

ALTER TABLE plate
	ADD COLUMN welloriginxunit bigint,
	ADD COLUMN welloriginyunit bigint;

ALTER TABLE shape
	ADD COLUMN fontsizeunit bigint,
	ADD COLUMN strokewidthunit bigint,
	ALTER COLUMN fontsize TYPE double precision /* TYPE change - table: shape original: integer new: double precision */,
	ALTER COLUMN strokewidth TYPE double precision /* TYPE change - table: shape original: integer new: double precision */;

ALTER TABLE stagelabel
	ADD COLUMN positionxunit bigint,
	ADD COLUMN positionyunit bigint,
	ADD COLUMN positionzunit bigint;

ALTER TABLE transmittancerange
	ADD COLUMN cutinunit bigint,
	ADD COLUMN cutintoleranceunit bigint,
	ADD COLUMN cutoutunit bigint,
	ADD COLUMN cutouttoleranceunit bigint,
	ALTER COLUMN cutin TYPE double precision /* TYPE change - table: transmittancerange original: positive_int new: double precision */,
	ALTER COLUMN cutintolerance TYPE double precision /* TYPE change - table: transmittancerange original: nonnegative_int new: double precision */,
	ALTER COLUMN cutout TYPE double precision /* TYPE change - table: transmittancerange original: positive_int new: double precision */,
	ALTER COLUMN cutouttolerance TYPE double precision /* TYPE change - table: transmittancerange original: nonnegative_int new: double precision */;

ALTER TABLE wellsample
	ADD COLUMN posxunit bigint,
	ADD COLUMN posyunit bigint;

ALTER TABLE unitselectricpotential
	ADD CONSTRAINT unitselectricpotential_pkey PRIMARY KEY (id);

ALTER TABLE unitsfrequency
	ADD CONSTRAINT unitsfrequency_pkey PRIMARY KEY (id);

ALTER TABLE unitslength
	ADD CONSTRAINT unitslength_pkey PRIMARY KEY (id);

ALTER TABLE unitspower
	ADD CONSTRAINT unitspower_pkey PRIMARY KEY (id);

ALTER TABLE unitspressure
	ADD CONSTRAINT unitspressure_pkey PRIMARY KEY (id);

ALTER TABLE unitstemperature
	ADD CONSTRAINT unitstemperature_pkey PRIMARY KEY (id);

ALTER TABLE detector
	ADD CONSTRAINT fk3e7b17c64067255c FOREIGN KEY (voltageunit) REFERENCES unitselectricpotential(id);

ALTER TABLE detectorsettings
	ADD CONSTRAINT fkbbe4ade94067255c FOREIGN KEY (voltageunit) REFERENCES unitselectricpotential(id);

ALTER TABLE detectorsettings
	ADD CONSTRAINT fkbbe4ade9b965e6b1 FOREIGN KEY (readoutrateunit) REFERENCES unitsfrequency(id);

ALTER TABLE imagingenvironment
	ADD CONSTRAINT fkcb554fbb2994f5bf FOREIGN KEY (airpressureunit) REFERENCES unitspressure(id);

ALTER TABLE imagingenvironment
	ADD CONSTRAINT fkcb554fbbe4886d25 FOREIGN KEY (temperatureunit) REFERENCES unitstemperature(id);

ALTER TABLE laser
	ADD CONSTRAINT fk61fbecb6793e9b0 FOREIGN KEY (wavelengthunit) REFERENCES unitslength(id);

ALTER TABLE laser
	ADD CONSTRAINT fk61fbecbaf8fc42a FOREIGN KEY (repetitionrateunit) REFERENCES unitsfrequency(id);

ALTER TABLE lightsettings
	ADD CONSTRAINT fk71827b396793e9b0 FOREIGN KEY (wavelengthunit) REFERENCES unitslength(id);

ALTER TABLE lightsource
	ADD CONSTRAINT fka080f4b199b88287 FOREIGN KEY (powerunit) REFERENCES unitspower(id);

ALTER TABLE logicalchannel
	ADD CONSTRAINT fk8406f4da5a95c867 FOREIGN KEY (pinholesizeunit) REFERENCES unitslength(id);

ALTER TABLE logicalchannel
	ADD CONSTRAINT fk8406f4dad028cf11 FOREIGN KEY (emissionwaveunit) REFERENCES unitslength(id);

ALTER TABLE logicalchannel
	ADD CONSTRAINT fk8406f4daf9c88b24 FOREIGN KEY (excitationwaveunit) REFERENCES unitslength(id);

ALTER TABLE objective
	ADD CONSTRAINT fka736b93927b31537 FOREIGN KEY (workingdistanceunit) REFERENCES unitslength(id);

ALTER TABLE pixels
	ADD CONSTRAINT fkc51e7eadbd72c031 FOREIGN KEY (physicalsizexunit) REFERENCES unitslength(id);

ALTER TABLE pixels
	ADD CONSTRAINT fkc51e7eadbd80d7b2 FOREIGN KEY (physicalsizeyunit) REFERENCES unitslength(id);

ALTER TABLE pixels
	ADD CONSTRAINT fkc51e7eadbd8eef33 FOREIGN KEY (physicalsizezunit) REFERENCES unitslength(id);

ALTER TABLE planeinfo
	ADD CONSTRAINT fk7da1b10abb655f00 FOREIGN KEY (positionxunit) REFERENCES unitslength(id);

ALTER TABLE planeinfo
	ADD CONSTRAINT fk7da1b10abb737681 FOREIGN KEY (positionyunit) REFERENCES unitslength(id);

ALTER TABLE planeinfo
	ADD CONSTRAINT fk7da1b10abb818e02 FOREIGN KEY (positionzunit) REFERENCES unitslength(id);

ALTER TABLE plate
	ADD CONSTRAINT fk65cdb16a2acf195 FOREIGN KEY (welloriginxunit) REFERENCES unitslength(id);

ALTER TABLE plate
	ADD CONSTRAINT fk65cdb16a2bb0916 FOREIGN KEY (welloriginyunit) REFERENCES unitslength(id);

ALTER TABLE shape
	ADD CONSTRAINT fk6854fa15674859f FOREIGN KEY (strokewidthunit) REFERENCES unitslength(id);

ALTER TABLE shape
	ADD CONSTRAINT fk6854fa17384e6e1 FOREIGN KEY (fontsizeunit) REFERENCES unitslength(id);

ALTER TABLE stagelabel
	ADD CONSTRAINT fk436ceab6bb655f00 FOREIGN KEY (positionxunit) REFERENCES unitslength(id);

ALTER TABLE stagelabel
	ADD CONSTRAINT fk436ceab6bb737681 FOREIGN KEY (positionyunit) REFERENCES unitslength(id);

ALTER TABLE stagelabel
	ADD CONSTRAINT fk436ceab6bb818e02 FOREIGN KEY (positionzunit) REFERENCES unitslength(id);

ALTER TABLE transmittancerange
	ADD CONSTRAINT fk60026a0a6502152 FOREIGN KEY (cutouttoleranceunit) REFERENCES unitslength(id);

ALTER TABLE transmittancerange
	ADD CONSTRAINT fk60026a0a8641c9dd FOREIGN KEY (cutoutunit) REFERENCES unitslength(id);

ALTER TABLE transmittancerange
	ADD CONSTRAINT fk60026a0ae231ec17 FOREIGN KEY (cutintoleranceunit) REFERENCES unitslength(id);

ALTER TABLE transmittancerange
	ADD CONSTRAINT fk60026a0afc9cdd78 FOREIGN KEY (cutinunit) REFERENCES unitslength(id);

ALTER TABLE unitselectricpotential
	ADD CONSTRAINT unitselectricpotential_external_id_key UNIQUE (external_id);

ALTER TABLE unitselectricpotential
	ADD CONSTRAINT unitselectricpotential_value_key UNIQUE (value);

ALTER TABLE unitselectricpotential
	ADD CONSTRAINT fkunitselectricpotential_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE unitsfrequency
	ADD CONSTRAINT unitsfrequency_external_id_key UNIQUE (external_id);

ALTER TABLE unitsfrequency
	ADD CONSTRAINT unitsfrequency_value_key UNIQUE (value);

ALTER TABLE unitsfrequency
	ADD CONSTRAINT fkunitsfrequency_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE unitslength
	ADD CONSTRAINT unitslength_external_id_key UNIQUE (external_id);

ALTER TABLE unitslength
	ADD CONSTRAINT unitslength_value_key UNIQUE (value);

ALTER TABLE unitslength
	ADD CONSTRAINT fkunitslength_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE unitspower
	ADD CONSTRAINT unitspower_external_id_key UNIQUE (external_id);

ALTER TABLE unitspower
	ADD CONSTRAINT unitspower_value_key UNIQUE (value);

ALTER TABLE unitspower
	ADD CONSTRAINT fkunitspower_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE unitspressure
	ADD CONSTRAINT unitspressure_external_id_key UNIQUE (external_id);

ALTER TABLE unitspressure
	ADD CONSTRAINT unitspressure_value_key UNIQUE (value);

ALTER TABLE unitspressure
	ADD CONSTRAINT fkunitspressure_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE unitstemperature
	ADD CONSTRAINT unitstemperature_external_id_key UNIQUE (external_id);

ALTER TABLE unitstemperature
	ADD CONSTRAINT unitstemperature_value_key UNIQUE (value);

ALTER TABLE unitstemperature
	ADD CONSTRAINT fkunitstemperature_external_id_externalinfo FOREIGN KEY (external_id) REFERENCES externalinfo(id);

ALTER TABLE wellsample
	ADD CONSTRAINT fkfb0ac3f8a7de48b5 FOREIGN KEY (posxunit) REFERENCES unitslength(id);

ALTER TABLE wellsample
	ADD CONSTRAINT fkfb0ac3f8a7ec6036 FOREIGN KEY (posyunit) REFERENCES unitslength(id);

CREATE INDEX i_detector_voltage ON detector USING btree (voltage);

CREATE INDEX i_detectorsettings_readoutrate ON detectorsettings USING btree (readoutrate);

CREATE INDEX i_detectorsettings_voltage ON detectorsettings USING btree (voltage);

CREATE INDEX i_imagingenvironment_airpressure ON imagingenvironment USING btree (airpressure);

CREATE INDEX i_imagingenvironment_temperature ON imagingenvironment USING btree (temperature);

CREATE INDEX i_laser_repetitionrate ON laser USING btree (repetitionrate);

CREATE INDEX i_laser_wavelength ON laser USING btree (wavelength);

CREATE INDEX i_lightsettings_wavelength ON lightsettings USING btree (wavelength);

CREATE INDEX i_lightsource_power ON lightsource USING btree (power);

CREATE INDEX i_logicalchannel_emissionwave ON logicalchannel USING btree (emissionwave);

CREATE INDEX i_logicalchannel_excitationwave ON logicalchannel USING btree (excitationwave);

CREATE INDEX i_logicalchannel_pinholesize ON logicalchannel USING btree (pinholesize);

CREATE INDEX i_objective_workingdistance ON objective USING btree (workingdistance);

CREATE INDEX i_pixels_physicalsizex ON pixels USING btree (physicalsizex);

CREATE INDEX i_pixels_physicalsizey ON pixels USING btree (physicalsizey);

CREATE INDEX i_pixels_physicalsizez ON pixels USING btree (physicalsizez);

CREATE INDEX i_planeinfo_positionx ON planeinfo USING btree (positionx);

CREATE INDEX i_planeinfo_positiony ON planeinfo USING btree (positiony);

CREATE INDEX i_planeinfo_positionz ON planeinfo USING btree (positionz);

CREATE INDEX i_plate_welloriginx ON plate USING btree (welloriginx);

CREATE INDEX i_plate_welloriginy ON plate USING btree (welloriginy);

CREATE INDEX i_shape_fontsize ON shape USING btree (fontsize);

CREATE INDEX i_shape_strokewidth ON shape USING btree (strokewidth);

CREATE INDEX i_stagelabel_positionx ON stagelabel USING btree (positionx);

CREATE INDEX i_stagelabel_positiony ON stagelabel USING btree (positiony);

CREATE INDEX i_stagelabel_positionz ON stagelabel USING btree (positionz);

CREATE INDEX i_transmittancerange_cutin ON transmittancerange USING btree (cutin);

CREATE INDEX i_transmittancerange_cutintolerance ON transmittancerange USING btree (cutintolerance);

CREATE INDEX i_transmittancerange_cutout ON transmittancerange USING btree (cutout);

CREATE INDEX i_transmittancerange_cutouttolerance ON transmittancerange USING btree (cutouttolerance);

CREATE INDEX i_wellsample_posx ON wellsample USING btree (posx);

CREATE INDEX i_wellsample_posy ON wellsample USING btree (posy);

CREATE TRIGGER detector_annotation_link_event_trigger_insert
	AFTER INSERT ON detectorannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Detector');

CREATE TRIGGER dichroic_annotation_link_event_trigger_insert
	AFTER INSERT ON dichroicannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Dichroic');

CREATE TRIGGER filter_annotation_link_event_trigger_insert
	AFTER INSERT ON filterannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Filter');

CREATE TRIGGER instrument_annotation_link_event_trigger_insert
	AFTER INSERT ON instrumentannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Instrument');

CREATE TRIGGER lightpath_annotation_link_event_trigger_insert
	AFTER INSERT ON lightpathannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.LightPath');

CREATE TRIGGER lightsource_annotation_link_event_trigger_insert
	AFTER INSERT ON lightsourceannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.LightSource');

CREATE TRIGGER objective_annotation_link_event_trigger_insert
	AFTER INSERT ON objectiveannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.acquisition.Objective');

CREATE TRIGGER shape_annotation_link_event_trigger_insert
	AFTER INSERT ON shapeannotationlink
	FOR EACH ROW
	EXECUTE PROCEDURE annotation_link_event_trigger('ome.model.roi.Shape');

-- 5.1DEV__13: Manual adjustments, mostly from psql-footer.sql

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'YV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'ZV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'EV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'PV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'TV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'GV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'MV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'kV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'hV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'daV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'V','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'dV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'cV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'mV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'µV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'nV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'pV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'fV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'aV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'zV','SI.VOLT';

insert into unitselectricpotential (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitselectricpotential'),-35,'yV','SI.VOLT';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'YHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'ZHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'EHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'PHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'THz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'GHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'MHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'kHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'hHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'daHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'Hz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'dHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'cHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'mHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'µHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'nHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'pHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'fHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'aHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'zHz','SI.HERTZ';

insert into unitsfrequency (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitsfrequency'),-35,'yHz','SI.HERTZ';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Ym','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Zm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Em','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Pm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Tm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Gm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'Mm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'km','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'hm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'dam','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'m','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'dm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'cm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'mm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'µm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'nm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'pm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'fm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'am','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'zm','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'ym','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'angstrom','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'thou','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'li','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'in','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'ft','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'yd','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'mi','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'ua','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'ly','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'pc','SI.METRE';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'pt','Imperial.INCH';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'pixel','Pixel';

insert into unitslength (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitslength'),-35,'reference frame','ReferenceFrame';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'YW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'ZW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'EW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'PW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'TW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'GW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'MW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'kW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'hW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'daW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'W','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'dW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'cW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'mW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'µW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'nW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'pW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'fW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'aW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'zW','SI.WATT';

insert into unitspower (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspower'),-35,'yW','SI.WATT';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'YPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'ZPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'EPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'PPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'TPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'GPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'MPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'kPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'hPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'daPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'Pa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'dPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'cPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'mPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'µPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'nPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'pPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'fPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'aPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'zPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'yPa','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'Mbar','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'kbar','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'bar','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'dbar','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'mbar','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'atm','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'psi','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'Torr','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'mTorr','SI.PASCAL';

insert into unitspressure (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitspressure'),-35,'mm Hg','SI.PASCAL';

insert into unitstemperature (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstemperature'),-35,'K','SI.KELVIN';

insert into unitstemperature (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstemperature'),-35,'°C','SI.KELVIN';

insert into unitstemperature (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstemperature'),-35,'°R','SI.KELVIN';

insert into unitstemperature (id,permissions,value,measurementsystem)
    select ome_nextval('seq_unitstemperature'),-35,'°F','SI.KELVIN';

update pixels set timeincrementunit = (select id from unitstime where value = 's') where timeincrement is not null;

update planeinfo set deltatunit = (select id from unitstime where value = 's')  where deltat is not null;
update planeinfo set exposuretimeunit = (select id from unitstime where value = 's') where exposuretime is not null;

update detector set voltageunit = (select id from unitselectricpotential where value = 'V') where  voltageunit is not null;

update detectorsettings set readoutrateunit = (select id from unitsfrequency where value = 'MHz') where readoutrateunit is not null;
update detectorsettings set voltageunit = (select id from unitselectricpotential where value = 'V') where voltageunit is not null;

update imagingenvironment set airpressureunit = (select id from unitspressure where value = 'mbar') where airpressureunit is not null;
update imagingenvironment set temperatureunit = (select id from unitstemperature where value = '°C') where temperatureunit is not null;

update laser set repetitionrateunit = (select id from unitsfrequency where value = 'Hz') where repetitionrateunit is not null;
update laser set wavelengthunit = (select id from unitslength where value = 'nm') where wavelengthunit is not null;

update lightsettings set wavelengthunit = (select id from unitslength where value = 'nm') where wavelengthunit is not null;

update lightsource set powerunit = (select id from unitspower where value = 'mW') where powerunit is not null;

update logicalchannel set emissionwaveunit = (select id from unitslength where value = 'nm') where emissionwaveunit is not null;
update logicalchannel set excitationwaveunit = (select id from unitslength where value = 'nm') where excitationwaveunit is not null;
update logicalchannel set pinholesizeunit = (select id from unitslength where value = 'µm') where pinholesizeunit is not null;

update objective set workingdistanceunit = (select id from unitslength where value = 'µm') where workingdistanceunit is not null;

update pixels set physicalsizexunit = (select id from unitslength where value = 'µm') where physicalsizexunit is not null;
update pixels set physicalsizeyunit = (select id from unitslength where value = 'µm') where physicalsizeyunit is not null;
update pixels set physicalsizezunit = (select id from unitslength where value = 'µm') where physicalsizezunit is not null;

update planeinfo set positionxunit = (select id from unitslength where value = 'reference frame') where positionxunit is not null;
update planeinfo set positionyunit = (select id from unitslength where value = 'reference frame') where positionyunit is not null;
update planeinfo set positionzunit = (select id from unitslength where value = 'reference frame') where positionzunit is not null;

update plate set welloriginxunit = (select id from unitslength where value = 'reference frame') where welloriginxunit is not null;
update plate set welloriginyunit = (select id from unitslength where value = 'reference frame') where welloriginyunit is not null;

update shape set fontsizeunit = (select id from unitslength  where value = 'pt') where fontsizeunit is not null;
update shape set strokewidthunit = (select id from unitslength  where value = 'pixel') where strokewidthunit is not null;

update stagelabel set positionxunit = (select id from unitslength where value = 'reference frame') where positionxunit is not null;
update stagelabel set positionyunit = (select id from unitslength where value = 'reference frame') where positionyunit is not null;
update stagelabel set positionzunit = (select id from unitslength where value = 'reference frame') where positionzunit is not null;

update transmittancerange set cutinunit = (select id from unitslength where value = 'nm') where cutinunit is not null;
update transmittancerange set cutintoleranceunit = (select id from unitslength where value = 'nm') where cutintoleranceunit is not null;
update transmittancerange set cutoutunit = (select id from unitslength where value = 'nm') where cutoutunit is not null;
update transmittancerange set cutouttoleranceunit = (select id from unitslength where value = 'nm') where cutouttoleranceunit is not null;

update wellsample set posxunit = (select id from unitslength where value = 'reference frame') where posxunit is not null;
update wellsample set posyunit = (select id from unitslength where value = 'reference frame') where posyunit is not null;

-- reactivate not null constraints
alter table pixelstype alter column bitsize set not null;
alter table unitselectricpotential alter column measurementsystem set not null;
alter table unitsfrequency alter column measurementsystem set not null;
alter table unitslength alter column measurementsystem set not null;
alter table unitspressure alter column measurementsystem set not null;
alter table unitstemperature alter column measurementsystem set not null;
alter table unitstime alter column measurementsystem set not null;

--
-- FINISHED
--

UPDATE dbpatch SET message = 'Database updated.', finished = clock_timestamp()
    WHERE currentVersion  = 'OMERO5.1DEV' AND
          currentPatch    = 13            AND
          previousVersion = 'OMERO5.0'    AND
          previousPatch   = 0;

SELECT CHR(10)||CHR(10)||CHR(10)||'YOU HAVE SUCCESSFULLY UPGRADED YOUR DATABASE TO VERSION OMERO5.1DEV__13'||CHR(10)||CHR(10)||CHR(10) AS Status;

COMMIT;
