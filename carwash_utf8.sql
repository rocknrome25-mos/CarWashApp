--
-- PostgreSQL database dump
--

\restrict EsY5pYIvw1m8SMpJo1kiugZFEQTEBS0DgdULY0gzK0S2JjDxzMuoybTAObFD0gE

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: carwash
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO carwash;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: carwash
--

COMMENT ON SCHEMA public IS '';


--
-- Name: AuditType; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."AuditType" AS ENUM (
    'BOOKING_MOVE',
    'BOOKING_DELETE',
    'BOOKING_CHANGE_SERVICE',
    'BOOKING_CHANGE_BODYTYPE',
    'BOOKING_DISCOUNT',
    'BAY_CLOSE',
    'BAY_OPEN',
    'SHIFT_OPEN',
    'SHIFT_CLOSE',
    'CLIENT_BLOCK',
    'CLIENT_UNBLOCK',
    'BOOKING_START',
    'BOOKING_FINISH',
    'PAYMENT_MARKED',
    'WAITLIST_DELETE'
);


ALTER TYPE public."AuditType" OWNER TO carwash;

--
-- Name: BookingPhotoKind; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."BookingPhotoKind" AS ENUM (
    'BEFORE',
    'AFTER',
    'DAMAGE',
    'OTHER'
);


ALTER TYPE public."BookingPhotoKind" OWNER TO carwash;

--
-- Name: BookingStatus; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."BookingStatus" AS ENUM (
    'ACTIVE',
    'CANCELED',
    'COMPLETED',
    'PENDING_PAYMENT'
);


ALTER TYPE public."BookingStatus" OWNER TO carwash;

--
-- Name: ClientGender; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."ClientGender" AS ENUM (
    'MALE',
    'FEMALE'
);


ALTER TYPE public."ClientGender" OWNER TO carwash;

--
-- Name: PaymentKind; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."PaymentKind" AS ENUM (
    'DEPOSIT',
    'REMAINING',
    'EXTRA',
    'REFUND'
);


ALTER TYPE public."PaymentKind" OWNER TO carwash;

--
-- Name: PaymentMethodType; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."PaymentMethodType" AS ENUM (
    'CASH',
    'CARD',
    'CONTRACT'
);


ALTER TYPE public."PaymentMethodType" OWNER TO carwash;

--
-- Name: PlannedShiftStatus; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."PlannedShiftStatus" AS ENUM (
    'DRAFT',
    'PUBLISHED',
    'CANCELED'
);


ALTER TYPE public."PlannedShiftStatus" OWNER TO carwash;

--
-- Name: ServiceKind; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."ServiceKind" AS ENUM (
    'BASE',
    'ADDON'
);


ALTER TYPE public."ServiceKind" OWNER TO carwash;

--
-- Name: ServiceLaborCategory; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."ServiceLaborCategory" AS ENUM (
    'WASH',
    'CHEM'
);


ALTER TYPE public."ServiceLaborCategory" OWNER TO carwash;

--
-- Name: ShiftCashEventType; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."ShiftCashEventType" AS ENUM (
    'OPEN_FLOAT',
    'CASH_IN',
    'CASH_OUT',
    'CLOSE_COUNT',
    'HANDOVER',
    'KEEP_IN_DRAWER'
);


ALTER TYPE public."ShiftCashEventType" OWNER TO carwash;

--
-- Name: ShiftStatus; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."ShiftStatus" AS ENUM (
    'OPEN',
    'CLOSED'
);


ALTER TYPE public."ShiftStatus" OWNER TO carwash;

--
-- Name: UserRole; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."UserRole" AS ENUM (
    'ADMIN',
    'OWNER',
    'WASHER'
);


ALTER TYPE public."UserRole" OWNER TO carwash;

--
-- Name: WaitlistStatus; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."WaitlistStatus" AS ENUM (
    'WAITING',
    'INVITED',
    'CANCELED',
    'EXPIRED',
    'CONVERTED'
);


ALTER TYPE public."WaitlistStatus" OWNER TO carwash;

--
-- Name: WasherClockEventType; Type: TYPE; Schema: public; Owner: carwash
--

CREATE TYPE public."WasherClockEventType" AS ENUM (
    'CLOCK_IN',
    'CLOCK_OUT'
);


ALTER TYPE public."WasherClockEventType" OWNER TO carwash;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: AuditEvent; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."AuditEvent" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    type public."AuditType" NOT NULL,
    "locationId" text,
    "userId" text,
    "shiftId" text,
    "bookingId" text,
    "clientId" text,
    reason text,
    payload jsonb
);


ALTER TABLE public."AuditEvent" OWNER TO carwash;

--
-- Name: Bay; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Bay" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "locationId" text NOT NULL,
    number integer NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "closedReason" text,
    "closedAt" timestamp(3) without time zone,
    "reopenedAt" timestamp(3) without time zone
);


ALTER TABLE public."Bay" OWNER TO carwash;

--
-- Name: Booking; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Booking" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "dateTime" timestamp(3) without time zone NOT NULL,
    "carId" text NOT NULL,
    "serviceId" text NOT NULL,
    status public."BookingStatus" DEFAULT 'PENDING_PAYMENT'::public."BookingStatus" NOT NULL,
    "canceledAt" timestamp(3) without time zone,
    "cancelReason" text,
    "paymentDueAt" timestamp(3) without time zone,
    "bayId" integer DEFAULT 1 NOT NULL,
    "bufferMin" integer DEFAULT 0 NOT NULL,
    comment text,
    "depositRub" integer DEFAULT 0 NOT NULL,
    "clientId" text,
    "locationId" text NOT NULL,
    "adminNote" text,
    "finishedAt" timestamp(3) without time zone,
    "shiftId" text,
    "startedAt" timestamp(3) without time zone,
    "discountNote" text,
    "discountRub" integer DEFAULT 0 NOT NULL,
    "requestedBayId" integer
);


ALTER TABLE public."Booking" OWNER TO carwash;

--
-- Name: BookingAddon; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."BookingAddon" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "bookingId" text NOT NULL,
    "serviceId" text NOT NULL,
    qty integer DEFAULT 1 NOT NULL,
    "priceRubSnapshot" integer NOT NULL,
    "durationMinSnapshot" integer NOT NULL,
    note text,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."BookingAddon" OWNER TO carwash;

--
-- Name: BookingPhoto; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."BookingPhoto" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "bookingId" text NOT NULL,
    kind public."BookingPhotoKind" NOT NULL,
    url text NOT NULL,
    note text,
    "uploadedByUserId" text
);


ALTER TABLE public."BookingPhoto" OWNER TO carwash;

--
-- Name: Car; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Car" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "makeDisplay" text NOT NULL,
    "modelDisplay" text NOT NULL,
    "plateDisplay" text NOT NULL,
    "makeNormalized" text NOT NULL,
    "modelNormalized" text NOT NULL,
    "plateNormalized" text NOT NULL,
    year integer,
    color text,
    "bodyType" text,
    "clientId" text
);


ALTER TABLE public."Car" OWNER TO carwash;

--
-- Name: Client; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Client" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    phone text NOT NULL,
    name text,
    gender public."ClientGender",
    "birthDate" timestamp(3) without time zone,
    "blockReason" text,
    "blockedAt" timestamp(3) without time zone,
    "blockedByUserId" text,
    "isBlocked" boolean DEFAULT false NOT NULL
);


ALTER TABLE public."Client" OWNER TO carwash;

--
-- Name: ClientLocation; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."ClientLocation" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "clientId" text NOT NULL,
    "locationId" text NOT NULL,
    "isBlocked" boolean DEFAULT false NOT NULL,
    "blockReason" text,
    "blockedAt" timestamp(3) without time zone,
    "blockedByUserId" text,
    "lastVisitAt" timestamp(3) without time zone
);


ALTER TABLE public."ClientLocation" OWNER TO carwash;

--
-- Name: Location; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Location" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    name text NOT NULL,
    address text,
    "colorHex" text DEFAULT '#2D9CDB'::text NOT NULL,
    "baysCount" integer DEFAULT 2 NOT NULL,
    "tenantId" text DEFAULT 'demo-tenant'::text NOT NULL
);


ALTER TABLE public."Location" OWNER TO carwash;

--
-- Name: Payment; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Payment" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "paidAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "amountRub" integer NOT NULL,
    method text NOT NULL,
    kind public."PaymentKind" NOT NULL,
    "bookingId" text NOT NULL,
    "methodType" public."PaymentMethodType" DEFAULT 'CARD'::public."PaymentMethodType" NOT NULL
);


ALTER TABLE public."Payment" OWNER TO carwash;

--
-- Name: PlannedShift; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."PlannedShift" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "locationId" text NOT NULL,
    "createdByUserId" text NOT NULL,
    "startAt" timestamp(3) without time zone NOT NULL,
    "endAt" timestamp(3) without time zone NOT NULL,
    status public."PlannedShiftStatus" DEFAULT 'DRAFT'::public."PlannedShiftStatus" NOT NULL,
    note text
);


ALTER TABLE public."PlannedShift" OWNER TO carwash;

--
-- Name: PlannedShiftWasher; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."PlannedShiftWasher" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "plannedShiftId" text NOT NULL,
    "washerId" text NOT NULL,
    "plannedBayId" integer,
    note text
);


ALTER TABLE public."PlannedShiftWasher" OWNER TO carwash;

--
-- Name: Service; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Service" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    name text NOT NULL,
    "priceRub" integer NOT NULL,
    "durationMin" integer DEFAULT 30 NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    kind public."ServiceKind" DEFAULT 'BASE'::public."ServiceKind" NOT NULL,
    "locationId" text NOT NULL,
    "sortOrder" integer DEFAULT 100 NOT NULL,
    "laborCategory" public."ServiceLaborCategory" DEFAULT 'WASH'::public."ServiceLaborCategory" NOT NULL
);


ALTER TABLE public."Service" OWNER TO carwash;

--
-- Name: Shift; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Shift" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "locationId" text NOT NULL,
    "adminId" text NOT NULL,
    "openedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "closedAt" timestamp(3) without time zone,
    status public."ShiftStatus" DEFAULT 'OPEN'::public."ShiftStatus" NOT NULL,
    "plannedShiftId" text
);


ALTER TABLE public."Shift" OWNER TO carwash;

--
-- Name: ShiftCashEvent; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."ShiftCashEvent" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "shiftId" text NOT NULL,
    "locationId" text NOT NULL,
    "adminId" text NOT NULL,
    type public."ShiftCashEventType" NOT NULL,
    "amountRub" integer NOT NULL,
    note text
);


ALTER TABLE public."ShiftCashEvent" OWNER TO carwash;

--
-- Name: ShiftWasher; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."ShiftWasher" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "shiftId" text NOT NULL,
    "washerId" text NOT NULL,
    "bayId" integer NOT NULL,
    "percentWash" integer DEFAULT 30 NOT NULL,
    "percentChem" integer DEFAULT 40 NOT NULL,
    "clockInAt" timestamp(3) without time zone,
    "clockOutAt" timestamp(3) without time zone
);


ALTER TABLE public."ShiftWasher" OWNER TO carwash;

--
-- Name: Tenant; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."Tenant" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    name text NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."Tenant" OWNER TO carwash;

--
-- Name: TenantFeature; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."TenantFeature" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "tenantId" text NOT NULL,
    key text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    params jsonb
);


ALTER TABLE public."TenantFeature" OWNER TO carwash;

--
-- Name: User; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."User" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    phone text NOT NULL,
    name text,
    role public."UserRole" NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "locationId" text NOT NULL,
    "shiftOpenAt" timestamp(3) without time zone,
    "shiftCloseAt" timestamp(3) without time zone
);


ALTER TABLE public."User" OWNER TO carwash;

--
-- Name: WaitlistRequest; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."WaitlistRequest" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    status public."WaitlistStatus" DEFAULT 'WAITING'::public."WaitlistStatus" NOT NULL,
    "locationId" text NOT NULL,
    "desiredDateTime" timestamp(3) without time zone NOT NULL,
    "desiredBayId" integer,
    "clientId" text NOT NULL,
    "carId" text NOT NULL,
    "serviceId" text NOT NULL,
    comment text,
    reason text,
    "invitedAt" timestamp(3) without time zone,
    "convertedBookingId" text
);


ALTER TABLE public."WaitlistRequest" OWNER TO carwash;

--
-- Name: WasherClockEvent; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."WasherClockEvent" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "shiftWasherId" text NOT NULL,
    type public."WasherClockEventType" NOT NULL,
    at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."WasherClockEvent" OWNER TO carwash;

--
-- Name: WasherPayRule; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public."WasherPayRule" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "locationId" text NOT NULL,
    category public."ServiceLaborCategory" NOT NULL,
    percent integer DEFAULT 30 NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."WasherPayRule" OWNER TO carwash;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: carwash
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO carwash;

--
-- Data for Name: AuditEvent; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."AuditEvent" (id, "createdAt", type, "locationId", "userId", "shiftId", "bookingId", "clientId", reason, payload) FROM stdin;
cmknw3fwu0003p2fgs9yd16k2	2026-01-21 10:38:07.182	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknw3fwq0001p2fgxi97qmhf	\N	\N	SHIFT_OPEN	{"openedAt": "2026-01-21T10:38:07.177Z"}
cmknwwnxf0000p2j8wnnq8oz7	2026-01-21 11:00:50.595	SHIFT_OPEN	\N	\N	\N	\N	\N	\N	\N
cmknwwv860002p2j8ipuyctb7	2026-01-21 11:01:00.055	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknw3fwq0001p2fgxi97qmhf	\N	\N	SHIFT_CLOSE	{"closedAt": "2026-01-21T11:01:00.050Z"}
cmknx3fqu0006p2j87lgq34vm	2026-01-21 11:06:06.582	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknx3fqq0004p2j8uxfsjaue	\N	\N	SHIFT_OPEN	{"openedAt": "2026-01-21T11:06:06.576Z"}
cmknx3u6l0007p2j85z9ih8cd	2026-01-21 11:06:25.293	SHIFT_OPEN	\N	\N	\N	\N	\N	\N	\N
cmknx52910009p2j8qqsnatdh	2026-01-21 11:07:22.406	BOOKING_MOVE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknx3fqq0004p2j8uxfsjaue	cmknvdsg50004p2ewz1lpah60	cmkmkxaco0000p2mkg7qvjdr3	Сдвиг из-за задержки предыдущего клиента	{"newValue": {"bayId": 1, "dateTime": "2026-01-21T11:30:00.000Z"}, "oldValue": {"bayId": 1, "dateTime": "2026-01-21T10:30:00.000Z"}, "clientAgreed": true}
cmknx5c10000bp2j84rcm3p1u	2026-01-21 11:07:35.077	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknx3fqq0004p2j8uxfsjaue	\N	\N	SHIFT_CLOSE	{"closedAt": "2026-01-21T11:07:35.072Z"}
cmknyniwb0003p2u49nphgngf	2026-01-21 11:49:43.403	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyniw60001p2u40eyl53t8	\N	\N	SHIFT_OPEN	{"openedAt": "2026-01-21T11:49:43.397Z"}
cmknynx6y0005p2u4t5bnjtpp	2026-01-21 11:50:01.931	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyniw60001p2u40eyl53t8	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_START	{"startedAt": "2026-01-21T11:00:50.588Z"}
cmknyo3vw0007p2u4ceskbf3s	2026-01-21 11:50:10.605	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyniw60001p2u40eyl53t8	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_FINISH	{"finishedAt": "2026-01-21T11:07:28.813Z"}
cmknyox870009p2u4s2tdcfbk	2026-01-21 11:50:48.632	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyniw60001p2u40eyl53t8	\N	\N	SHIFT_CLOSE	{"closedAt": "2026-01-21T11:50:48.627Z"}
cmknyp33i000dp2u45e4o1g4m	2026-01-21 11:50:56.238	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyp33e000bp2u47hhrjs9a	\N	\N	SHIFT_OPEN	{"openedAt": "2026-01-21T11:50:56.233Z"}
cmknypo0j000fp2u497i1zug8	2026-01-21 11:51:23.348	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyp33e000bp2u47hhrjs9a	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_START	{"startedAt": "2026-01-21T11:00:50.588Z"}
cmknypspi000hp2u4x3zom1tr	2026-01-21 11:51:29.43	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyp33e000bp2u47hhrjs9a	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_FINISH	{"finishedAt": "2026-01-21T11:07:28.813Z"}
cmknysbnq000jp2u4qqs71iqs	2026-01-21 11:53:27.303	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyp33e000bp2u47hhrjs9a	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_START	{"startedAt": "2026-01-21T11:00:50.588Z"}
cmknytuxc000lp2u4jtnaqjbb	2026-01-21 11:54:38.928	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyp33e000bp2u47hhrjs9a	\N	\N	SHIFT_CLOSE	{"closedAt": "2026-01-21T11:54:38.923Z"}
cmknyu178000pp2u41gnl60fw	2026-01-21 11:54:47.06	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyu174000np2u409u0ga9g	\N	\N	SHIFT_OPEN	{"openedAt": "2026-01-21T11:54:47.056Z"}
cmknz7f9m000rp2u4xo4oq5u9	2026-01-21 12:05:11.819	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyu174000np2u409u0ga9g	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_START	{"startedAt": "2026-01-21T11:00:50.588Z"}
cmknz7it2000tp2u4wmoqgcpz	2026-01-21 12:05:16.407	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyu174000np2u409u0ga9g	cmknvdsg50004p2ewz1lpah60	\N	BOOKING_FINISH	{"finishedAt": "2026-01-21T11:07:28.813Z"}
cmknz7wi6000vp2u4zq4ieoh5	2026-01-21 12:05:34.159	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmknyu174000np2u409u0ga9g	\N	\N	SHIFT_CLOSE	{"closedAt": "2026-01-21T12:05:34.154Z"}
cmkpbsiej0003p2hw92etsu1h	2026-01-22 10:45:17.227	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpbsiec0001p2hwb3ncd27k	\N	\N	SHIFT_OPEN	\N
cmkpbt2uk000dp2hwtn0b41wh	2026-01-22 10:45:43.724	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpbsiec0001p2hwb3ncd27k	\N	\N	SHIFT_CLOSE	\N
cmkpc8kq3001ep2hwgk3useaw	2026-01-22 10:57:46.731	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	\N	\N	SHIFT_OPEN	\N
cmkpc912e001ip2hwp6ibo3sv	2026-01-22 10:58:07.91	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc6nkf000ip2hwdkfxue52	\N	BOOKING_START	\N
cmkpc9d2l001kp2hwcp8egu3z	2026-01-22 10:58:23.47	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc8gvh0018p2hw0u7t4zq2	\N	BOOKING_START	\N
cmkpc9k5z001mp2hwzh1l09ou	2026-01-22 10:58:32.663	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc8gvh0018p2hw0u7t4zq2	\N	BOOKING_FINISH	\N
cmkpc9rks001op2hwwy1izox1	2026-01-22 10:58:42.268	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc74ag000qp2hw74hpncwl	\N	BOOKING_START	\N
cmkpc9txj001qp2hwhtwf6819	2026-01-22 10:58:45.32	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc74ag000qp2hw74hpncwl	\N	BOOKING_FINISH	\N
cmkpc9y3u001sp2hwybjr4kfc	2026-01-22 10:58:50.73	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	cmkpc6nkf000ip2hwdkfxue52	\N	BOOKING_FINISH	\N
cmkpcagn90020p2hwj757qkn6	2026-01-22 10:59:14.758	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpc8kpv001cp2hwde2cb78j	\N	\N	SHIFT_CLOSE	\N
cmkpi9maq0003p2r8vzcdhwdu	2026-01-22 13:46:33.123	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpi9mak0001p2r8ws7b6upn	\N	\N	SHIFT_OPEN	\N
cmkpi9z11000dp2r8i2m97l9c	2026-01-22 13:46:49.621	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpi9mak0001p2r8ws7b6upn	\N	\N	SHIFT_CLOSE	\N
cmkpifybi000zp2r8u0mpb3u8	2026-01-22 13:51:28.638	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	\N	\N	SHIFT_OPEN	\N
cmkpikry50013p2r8t084m2f0	2026-01-22 13:55:13.662	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	cmkpib7ah000ip2r819n1tb0o	\N	BOOKING_START	\N
cmkpil6s50015p2r8k2bgujsy	2026-01-22 13:55:32.885	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	cmkpib7ah000ip2r819n1tb0o	\N	BOOKING_FINISH	\N
cmkpim8ek0017p2r8j2429n0t	2026-01-22 13:56:21.644	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	cmkpic252000tp2r8ko660d4h	\N	BOOKING_START	\N
cmkpimag20019p2r8baivn88g	2026-01-22 13:56:24.291	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	cmkpic252000tp2r8ko660d4h	\N	BOOKING_FINISH	\N
cmkpint5e001hp2r8mo2qyqe2	2026-01-22 13:57:35.186	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpifybc000xp2r8h7u0torl	\N	\N	SHIFT_CLOSE	\N
cmkpj7h9b001lp2r82yo9gd86	2026-01-22 14:12:52.895	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpj7h92001jp2r8xdw0vcxv	\N	\N	SHIFT_OPEN	\N
cmkpjbumu0022p2r8w22152nx	2026-01-22 14:16:16.855	BOOKING_MOVE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpj7h92001jp2r8xdw0vcxv	cmkpjavnl001sp2r88rg34zdl	cmkmkxaco0000p2mkg7qvjdr3	Сдвиг из-за задержки	{"newValue": {"bayId": 1, "dateTime": "2026-01-24T03:00:00.000Z"}, "oldValue": {"bayId": 1, "dateTime": "2026-01-23T03:00:00.000Z"}, "clientAgreed": true}
cmkplhuwa000dp2ncwq6ktq6q	2026-01-22 15:16:56.363	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpj7h92001jp2r8xdw0vcxv	cmkplcrkt0009p2nc8l1jl6oe	\N	BOOKING_START	\N
cmkpli2ta000fp2nchy0xifub	2026-01-22 15:17:06.623	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpj7h92001jp2r8xdw0vcxv	cmkplcrkt0009p2nc8l1jl6oe	\N	BOOKING_FINISH	\N
cmkpliheg000hp2nc4obts7ey	2026-01-22 15:17:25.528	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpj7h92001jp2r8xdw0vcxv	\N	\N	SHIFT_CLOSE	\N
cmkpm7199000lp2nchdxeyb7y	2026-01-22 15:36:31.005	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpm7195000jp2nc7kkxbsbo	\N	\N	SHIFT_OPEN	\N
cmkpm7dkh000pp2ncj5bjdghw	2026-01-22 15:36:46.961	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpm7195000jp2nc7kkxbsbo	cmkpjba16001yp2r89mp9rlm0	\N	BOOKING_START	\N
cmkpm7r2j000rp2nc7paqfbnn	2026-01-22 15:37:04.46	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpm7195000jp2nc7kkxbsbo	cmkpjba16001yp2r89mp9rlm0	\N	BOOKING_FINISH	\N
cmkpm8b8y000zp2nc3tqfle92	2026-01-22 15:37:30.611	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpm7195000jp2nc7kkxbsbo	\N	\N	SHIFT_CLOSE	\N
cmkpnaocf0013p2nc8kugww6m	2026-01-22 16:07:20.511	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpnaoca0011p2ncigt4t3ow	\N	\N	SHIFT_OPEN	\N
cmkpp5wyq0007p20oj7s605k4	2026-01-22 16:59:37.634	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpnaoca0011p2ncigt4t3ow	\N	\N	SHIFT_CLOSE	\N
cmkpp61g3000bp20oihtzriw8	2026-01-22 16:59:43.443	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpp61fx0009p20o9u1bfssf	\N	\N	SHIFT_OPEN	\N
cmksh8lhx0001p2ksu1t0maqg	2026-01-24 15:41:04.341	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpp61fx0009p20o9u1bfssf	cmkpjavnl001sp2r88rg34zdl	\N	BOOKING_START	\N
cmksh911y0005p2kshy570u4k	2026-01-24 15:41:24.503	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpp61fx0009p20o9u1bfssf	cmkpjavnl001sp2r88rg34zdl	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2000, "methodType": "CASH"}
cmksh95v10007p2ks3sks82ej	2026-01-24 15:41:30.734	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpp61fx0009p20o9u1bfssf	cmkpjavnl001sp2r88rg34zdl	\N	BOOKING_FINISH	\N
cmktoq1gv000wp2xgwachvcgo	2026-01-25 11:58:21.679	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkpp61fx0009p20o9u1bfssf	\N	\N	SHIFT_CLOSE	\N
cmktoqp8z0010p2xgfx40vglr	2026-01-25 11:58:52.5	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	\N	\N	SHIFT_OPEN	\N
cmktorxf40014p2xg3oopdgqg	2026-01-25 11:59:49.745	BOOKING_DISCOUNT	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktooca20004p2xg7bqda9ej	cmkmkxaco0000p2mkg7qvjdr3	захотел	{"newDiscountRub": 500, "oldDiscountRub": 0}
cmktostna0018p2xg7ijl4m11	2026-01-25 12:00:31.51	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktooca20004p2xg7bqda9ej	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cmktosx7p001ap2xgwch1xsqm	2026-01-25 12:00:36.133	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktooca20004p2xg7bqda9ej	\N	BOOKING_START	\N
cmktotyg0001cp2xgbkvc29xv	2026-01-25 12:01:24.384	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktooca20004p2xg7bqda9ej	\N	BOOKING_FINISH	\N
cmktx6wee0008p20soltr1mjn	2026-01-25 15:55:25.19	BOOKING_DISCOUNT	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktx5ppn0004p20s11xrlht1	cmkmkxaco0000p2mkg7qvjdr3	лояльный клиент	{"newDiscountRub": 300, "oldDiscountRub": 0}
cmktx7fei000cp20s9cb4v9yp	2026-01-25 15:55:49.819	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktx5ppn0004p20s11xrlht1	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1700, "methodType": "CASH"}
cmktx7ooe000ep20so21j6m61	2026-01-25 15:56:01.839	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktx5ppn0004p20s11xrlht1	\N	BOOKING_START	\N
cmktx8z3k000gp20sb4pm3ud3	2026-01-25 15:57:02	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	cmktx5ppn0004p20s11xrlht1	\N	BOOKING_FINISH	\N
cmktx9cyy000op20sqwqv2wy1	2026-01-25 15:57:19.978	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktoqp8u000yp2xgbr5yphlh	\N	\N	SHIFT_CLOSE	\N
cmktxawpl000sp20s7ldfny17	2026-01-25 15:58:32.218	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	\N	\N	SHIFT_OPEN	\N
cmktxd998000wp20slkbgvi5y	2026-01-25 16:00:21.789	BOOKING_DISCOUNT	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	cmktoonlj000ap2xgyir0z8f2	cmkmkxaco0000p2mkg7qvjdr3	карта лояльности №123	{"newDiscountRub": 300, "oldDiscountRub": 0}
cmktxeavf0010p20s73aheuia	2026-01-25 16:01:10.539	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	cmktoonlj000ap2xgyir0z8f2	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1700, "methodType": "CASH"}
cmktxelri0012p20sui4cnmk5	2026-01-25 16:01:24.655	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	cmktoonlj000ap2xgyir0z8f2	\N	BOOKING_START	\N
cmktxfbzi0014p20s1ljpdm17	2026-01-25 16:01:58.639	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	cmktoonlj000ap2xgyir0z8f2	\N	BOOKING_FINISH	\N
cmkwf90zc0007p2h0uvd84ucv	2026-01-27 09:56:29.88	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmktxawpg000qp20s1x1673ae	\N	\N	SHIFT_CLOSE	\N
cmkwfanh2000bp2h0isz1grrh	2026-01-27 09:57:45.687	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfangy0009p2h0mde3w2ej	\N	\N	SHIFT_OPEN	\N
cmkwfye57000lp2h0n19c4qrp	2026-01-27 10:16:13.339	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfangy0009p2h0mde3w2ej	\N	\N	SHIFT_CLOSE	\N
cmkwfyicw000pp2h0g7jd421k	2026-01-27 10:16:18.8	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	SHIFT_OPEN	\N
cmkwfz7av000tp2h0fg75lpgg	2026-01-27 10:16:51.127	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmkwfzgkj000vp2h0jl04f2wv	2026-01-27 10:17:03.139	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmkwglc2b000xp2h0b9f9tite	2026-01-27 10:34:03.731	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkwglf6c000zp2h015ptu0ir	2026-01-27 10:34:07.764	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmkwglmi70017p2h0nys7su4s	2026-01-27 10:34:17.263	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwfyick000np2h0b41mb93x	\N	\N	SHIFT_CLOSE	\N
cmkwgnf6e001bp2h0hhn3ejg7	2026-01-27 10:35:41.078	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgnf6a0019p2h0elstr25j	\N	\N	SHIFT_OPEN	\N
cmkwgpeiz001lp2h048d0jp83	2026-01-27 10:37:13.547	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgnf6a0019p2h0elstr25j	\N	\N	SHIFT_CLOSE	\N
cmkwgplj4001pp2h0lle5g4f9	2026-01-27 10:37:22.625	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgplj1001np2h0jqz46k84	\N	\N	SHIFT_OPEN	\N
cmkwgrvi8001tp2h0r2e886ua	2026-01-27 10:39:08.865	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgplj1001np2h0jqz46k84	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkwgs38k001vp2h0im7oem5r	2026-01-27 10:39:18.884	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgplj1001np2h0jqz46k84	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmkwgspnq001xp2h0qnrp6m0x	2026-01-27 10:39:47.942	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgplj1001np2h0jqz46k84	\N	\N	пропропрпропр	{"isActive": false, "bayNumber": 1}
cmkwgtb9z0025p2h0369pmy7b	2026-01-27 10:40:15.959	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgplj1001np2h0jqz46k84	\N	\N	SHIFT_CLOSE	\N
cmkwgzjke0029p2h0u4ouw70l	2026-01-27 10:45:06.638	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgzjk80027p2h07slf52sv	\N	\N	SHIFT_OPEN	\N
cmkwh746w002jp2h0knbcyt4n	2026-01-27 10:50:59.96	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwgzjk80027p2h07slf52sv	\N	\N	SHIFT_CLOSE	\N
cmkwh76jy002np2h0euo9x5dm	2026-01-27 10:51:03.023	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwh76jv002lp2h075pu3waa	\N	\N	SHIFT_OPEN	\N
cmkwh7hiq002rp2h078typ6b6	2026-01-27 10:51:17.234	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwh76jv002lp2h075pu3waa	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkwh8szj002tp2h098eotp93	2026-01-27 10:52:18.751	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwh76jv002lp2h075pu3waa	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmkwh8uam002vp2h0kckcgch9	2026-01-27 10:52:20.446	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwh76jv002lp2h075pu3waa	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmkwk6xtn0007p2wkett5z4bs	2026-01-27 12:14:50.555	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwh76jv002lp2h075pu3waa	\N	\N	SHIFT_CLOSE	\N
cmkwkgrim000bp2wkwwxtdgq5	2026-01-27 12:22:28.943	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	\N	\N	SHIFT_OPEN	\N
cmkwki289000fp2wkuic4y5df	2026-01-27 12:23:29.481	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	cmktooxq1000gp2xgfz6olghk	\N	BOOKING_START	\N
cmkwn9lew0003p2cg1ss02gr1	2026-01-27 13:40:53.289	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	cmktooxq1000gp2xgfz6olghk	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2000, "methodType": "CASH"}
cmkwn9oqz0005p2cgkwvrpian	2026-01-27 13:40:57.612	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	cmktooxq1000gp2xgfz6olghk	\N	BOOKING_FINISH	\N
cmkwna68p0007p2cgkus63xvs	2026-01-27 13:41:20.281	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkwna9of0009p2cg4c17bnox	2026-01-27 13:41:24.736	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmkwnathm000hp2cgpvaarga3	2026-01-27 13:41:50.41	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwkgrii0009p2wkhm9ghj5d	\N	\N	SHIFT_CLOSE	\N
cmkwnax2z000lp2cgnmyb2wra	2026-01-27 13:41:55.068	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnax2v000jp2cg6kboq12k	\N	\N	SHIFT_OPEN	\N
cmkwnb2qp000pp2cgmq9js0hf	2026-01-27 13:42:02.401	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnax2v000jp2cg6kboq12k	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmkwnb41z000rp2cg7s6pdhyq	2026-01-27 13:42:04.103	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnax2v000jp2cg6kboq12k	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmkwnejyu000zp2cgz7tc890e	2026-01-27 13:44:44.694	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnax2v000jp2cg6kboq12k	\N	\N	SHIFT_CLOSE	\N
cmkwnm9r9001ep2cg95vwfd5q	2026-01-27 13:50:44.709	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnm9r5001cp2cgba3cj8y6	\N	\N	SHIFT_OPEN	\N
cmkwrxn4g0007p2a8aeblca9x	2026-01-27 15:51:33.713	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwnm9r5001cp2cgba3cj8y6	\N	\N	SHIFT_CLOSE	\N
cmkwrxphj000bp2a8xzhb98j9	2026-01-27 15:51:36.775	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	\N	\N	SHIFT_OPEN	\N
cmkwu0hsq000jp2wo5ornc6ke	2026-01-27 16:49:46.01	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkwu0ktp000lp2woj8js671s	2026-01-27 16:49:49.934	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	cmkws5uv0000ip2a8dd9uv3w2	\N	BOOKING_START	\N
cmkz4wt8j000ap2jwamcqozdn	2026-01-29 07:30:22.34	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	cmkz4vh2g0004p2jwuevwenl7	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2000, "methodType": "CASH"}
cmkz53hra0001p26guvcqbt4g	2026-01-29 07:35:34.055	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmkz53q930003p26gcv7kosa3	2026-01-29 07:35:45.063	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	cmkz4vh2g0004p2jwuevwenl7	\N	BOOKING_START	\N
cmkz54y5u0005p26gc0atzocn	2026-01-29 07:36:41.971	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	cmkz4vh2g0004p2jwuevwenl7	\N	BOOKING_FINISH	\N
cmkz55f31000dp26gu6xb9drd	2026-01-29 07:37:03.901	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkwrxphf0009p2a8vo7zzyvz	\N	\N	SHIFT_CLOSE	\N
cmkz5aqw0000np26gsv0wiq99	2026-01-29 07:41:12.48	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5aqvv000lp26ghyy2x5qh	\N	\N	SHIFT_OPEN	\N
cmkz5boec000tp26gdvn3jxl1	2026-01-29 07:41:55.909	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5aqvv000lp26ghyy2x5qh	cmkz5ag3z000hp26g0rhmjixz	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 700, "methodType": "CASH"}
cmkz5c7c1000vp26gt3j6wjnb	2026-01-29 07:42:20.449	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5aqvv000lp26ghyy2x5qh	cmkz5ag3z000hp26g0rhmjixz	\N	BOOKING_START	\N
cmkz5cucp000xp26ga6bf5w5o	2026-01-29 07:42:50.281	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5aqvv000lp26ghyy2x5qh	cmkz5ag3z000hp26g0rhmjixz	\N	BOOKING_FINISH	\N
cmkz5dde80015p26gnglt7lx5	2026-01-29 07:43:14.96	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5aqvv000lp26ghyy2x5qh	\N	\N	SHIFT_CLOSE	\N
cmkz5kif8001fp26ggn62npx0	2026-01-29 07:48:48.069	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5kif5001dp26gfgh0tj6v	\N	\N	SHIFT_OPEN	\N
cmkz5mxkx001jp26grymbf2ib	2026-01-29 07:50:41.025	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5kif5001dp26gfgh0tj6v	cmkz5k8z40019p26g9gp7kr7e	\N	BOOKING_START	\N
cmkz5qpyg001lp26g9qmdw5xo	2026-01-29 07:53:37.769	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5kif5001dp26gfgh0tj6v	cmkz5k8z40019p26g9gp7kr7e	\N	BOOKING_FINISH	\N
cmkz6ebzh001zp26gz69hf008	2026-01-29 08:11:59.405	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz5kif5001dp26gfgh0tj6v	\N	\N	SHIFT_CLOSE	\N
cmkz6yyq40023p26gnit4404q	2026-01-29 08:28:01.996	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz6yyq00021p26gj0hyauv6	\N	\N	SHIFT_OPEN	\N
cmkz94gxw0009p2x0q4gxwlwp	2026-01-29 09:28:18.117	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz6yyq00021p26gj0hyauv6	\N	\N	SHIFT_CLOSE	\N
cmkz9lzjm000dp2x0jnyevoel	2026-01-29 09:41:55.378	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz9lzjh000bp2x0wuylm0vs	\N	\N	SHIFT_OPEN	\N
cmkza71m2000np2x0bbunwtmz	2026-01-29 09:58:17.834	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkz9lzjh000bp2x0wuylm0vs	\N	\N	SHIFT_CLOSE	\N
cmkzac50v0011p2x0kz2v8gba	2026-01-29 10:02:15.536	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzac50q000zp2x0p4i25xhj	\N	\N	SHIFT_OPEN	\N
cmkzagakh0015p2x0dj3axr5w	2026-01-29 10:05:29.345	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzac50q000zp2x0p4i25xhj	cmkza9jrh000rp2x0nftfy044	\N	BOOKING_START	\N
cmkzaiskd001fp2x0t98n9ksj	2026-01-29 10:07:25.981	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzac50q000zp2x0p4i25xhj	cmkza9jrh000rp2x0nftfy044	cmkmundtt0001p2lk2zc5xaxe	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2000, "methodType": "CASH"}
cmkzaj5y7001hp2x0lnv2sw3d	2026-01-29 10:07:43.327	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzac50q000zp2x0p4i25xhj	cmkza9jrh000rp2x0nftfy044	\N	BOOKING_FINISH	\N
cmkzavjuj001pp2x08pxsxziq	2026-01-29 10:17:21.212	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzac50q000zp2x0p4i25xhj	\N	\N	SHIFT_CLOSE	\N
cmkzgww1g0003p2ush73o6yy3	2026-01-29 13:06:21.365	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	SHIFT_OPEN	\N
cmkziyjj70001p2vwfxf8hz3i	2026-01-29 14:03:37.7	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmkziykuq0003p2vw361cq262	2026-01-29 14:03:39.41	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmkzj4fkj0009p2vw38v048tn	2026-01-29 14:08:12.499	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmkzj4g6q000bp2vw3nm0zexl	2026-01-29 14:08:13.298	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmkzktd45000np2vw4k9beshx	2026-01-29 14:55:35.333	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzgww1c0001p2us1trus4ky	\N	\N	SHIFT_CLOSE	\N
cmkzkubz2000rp2vwuiml30kg	2026-01-29 14:56:20.51	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzkubyx000pp2vwarch23mp	\N	\N	SHIFT_OPEN	\N
cmkzszpyl0006p2xcf8if0z6z	2026-01-29 18:44:28.846	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzkubyx000pp2vwarch23mp	cmkzgxv770009p2uspgaocfpg	\N	BOOKING_FINISH	\N
cml17le5h0007p2iw40js6u9y	2026-01-30 18:21:00.773	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmkzkubyx000pp2vwarch23mp	\N	\N	SHIFT_CLOSE	\N
cml182bh70008p2ps26fw6bom	2026-01-30 18:34:10.46	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	SHIFT_OPEN	\N
cml19bawd0001p25s0vi6r27b	2026-01-30 19:09:09.23	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cml19bc9y0003p25st5ke3ewo	2026-01-30 19:09:11.015	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cml1zf9rh0008p27o4nud04vs	2026-01-31 07:20:04.397	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cml1zfac0000ap27o3495kxwk	2026-01-31 07:20:05.136	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cml1zfcqt000cp27owj7bjd3f	2026-01-31 07:20:08.261	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cml1zfez0000ep27o85utmv2n	2026-01-31 07:20:11.148	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cml22oxgj0009p2fk8m72z09o	2026-01-31 08:51:33.859	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cml22oy0v000bp2fk6hshq745	2026-01-31 08:51:34.591	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cml23mieg0001p228n9umyg6w	2026-01-31 09:17:40.648	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2329i1001hp2fk9nkjc3g7	\N	BOOKING_FINISH	\N
cml2gr9nr0001p2042g26r63q	2026-01-31 15:25:17.607	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22ycf2000pp2fkvck6barn	\N	BOOKING_START	\N
cml2grfjx0005p2044imh3ksx	2026-01-31 15:25:25.245	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22ycf2000pp2fkvck6barn	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml2griql0007p20439hnwp5m	2026-01-31 15:25:29.373	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22ycf2000pp2fkvck6barn	\N	BOOKING_FINISH	\N
cml2grn350009p204v0lg04no	2026-01-31 15:25:35.01	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22p2fv000fp2fk4rx3xzc9	\N	BOOKING_START	\N
cml2grq4k000bp204098m9ufl	2026-01-31 15:25:38.948	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2308pl0013p2fkwsi368jv	\N	BOOKING_START	\N
cml2gs8fy000vp204zsygcpyo	2026-01-31 15:26:02.686	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2g1zmh000hp2b0piepww4r	\N	BOOKING_FINISH	\N
cml2grrlq000dp204l4axcwhn	2026-01-31 15:25:40.862	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2g1zmh000hp2b0piepww4r	\N	BOOKING_START	\N
cml2gruxf000hp2041y4aupel	2026-01-31 15:25:45.172	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22p2fv000fp2fk4rx3xzc9	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml2grwrf000jp204jb5ew7o2	2026-01-31 15:25:47.548	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml22p2fv000fp2fk4rx3xzc9	\N	BOOKING_FINISH	\N
cml2gs0hf000np2044m79wupe	2026-01-31 15:25:52.371	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2308pl0013p2fkwsi368jv	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml2gs2d6000pp204i8enghbq	2026-01-31 15:25:54.81	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2308pl0013p2fkwsi368jv	\N	BOOKING_FINISH	\N
cml2gs5xu000tp2044vq9fgir	2026-01-31 15:25:59.442	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	cml2g1zmh000hp2b0piepww4r	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml2gtdqn0013p20403aonwej	2026-01-31 15:26:56.208	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml182bh10006p2psuqbugxws	\N	\N	SHIFT_CLOSE	\N
cml3wl9ks000gp2f00k6dusl7	2026-02-01 15:36:17.596	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	SHIFT_OPEN	\N
cml3wlfv7000kp2f0r64ju9e5	2026-02-01 15:36:25.747	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cml3wlhb3000mp2f08ms7snfg	2026-02-01 15:36:27.615	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cml6cva75000ep23weumx6cem	2026-02-03 08:47:31.169	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cml6cvaor000gp23wfx3v30bz	2026-02-03 08:47:31.803	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cml6cyu3y000sp23w9vnkq3d5	2026-02-03 08:50:16.942	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6cvsrd000kp23w8zq5jm4e	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6cyxz7000up23w5sll9odl	2026-02-03 08:50:21.956	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6cvsrd000kp23w8zq5jm4e	\N	BOOKING_START	\N
cml6dtfen000wp23wf6s1jjdn	2026-02-03 09:14:04.223	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6cvsrd000kp23w8zq5jm4e	\N	BOOKING_FINISH	\N
cml6gbfgc000dp2lcmmg2yus8	2026-02-03 10:24:03.324	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6ga6180005p2lcdnkf9li2	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6gbj9a000fp2lc1c51r69e	2026-02-03 10:24:08.254	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6ga6180005p2lcdnkf9li2	\N	BOOKING_START	\N
cml6gbn24000hp2lc4qlhscdq	2026-02-03 10:24:13.18	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6ga6180005p2lcdnkf9li2	\N	BOOKING_FINISH	\N
cml6idqbs000sp2lcfdz3f8d0	2026-02-03 11:21:49.961	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6idjz9000mp2lco5wz8sm3	\N	BOOKING_START	\N
cml6idzd5000wp2lcb2s0d2mk	2026-02-03 11:22:01.673	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	cml6idjz9000mp2lco5wz8sm3	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CARD", "amountRub": 2800, "methodType": "CARD"}
cml6izvpl0014p2lc3ywet8gu	2026-02-03 11:39:03.37	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml3wl9ko000ep2f0sc1te96f	\N	\N	SHIFT_CLOSE	\N
cml6j03hy0018p2lcute29wku	2026-02-03 11:39:13.462	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	\N	\N	SHIFT_OPEN	\N
cml6k9bba001sp2lczqxypnti	2026-02-03 12:14:23.111	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j0qfd001ep2lc68ealmwb	\N	BOOKING_START	\N
cml6kzzed000cp2eotqx5t4hz	2026-02-03 12:35:07.382	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6kzj9j0006p2eo1aomhp84	\N	BOOKING_START	\N
cml6l0b9e000gp2eohbo1maty	2026-02-03 12:35:22.754	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6kzj9j0006p2eo1aomhp84	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6l0xcy000ip2eow9q6cr7m	2026-02-03 12:35:51.394	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6kzj9j0006p2eo1aomhp84	\N	BOOKING_FINISH	\N
cml6lh6mt000ap21kq4do4hr8	2026-02-03 12:48:29.91	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lgfic0004p21kw7au9mfp	\N	BOOKING_START	\N
cml6lhfuz000ep21kuccwkfv6	2026-02-03 12:48:41.868	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lgfic0004p21kw7au9mfp	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6li5ab000gp21kn1ecjugg	2026-02-03 12:49:14.819	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lgfic0004p21kw7au9mfp	\N	BOOKING_FINISH	\N
cml6lpf7y000ip21krw2abynn	2026-02-03 12:54:54.286	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j1fe9001mp2lc6gvli0w9	\N	BOOKING_START	\N
cml6lpk98000mp21k4dck34x7	2026-02-03 12:55:00.812	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j1fe9001mp2lc6gvli0w9	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml6lpobd000op21knbaad9i4	2026-02-03 12:55:06.074	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j1fe9001mp2lc6gvli0w9	\N	BOOKING_FINISH	\N
cml6lpw1w000sp21k0y3cyz0o	2026-02-03 12:55:16.1	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j0qfd001ep2lc68ealmwb	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6lpylx000up21kjrihkajf	2026-02-03 12:55:19.413	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6j0qfd001ep2lc68ealmwb	\N	BOOKING_FINISH	\N
cml6nd1t4000cp2vw5tskxxw6	2026-02-03 13:41:16.264	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6nbucc0004p2vwguixqxss	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cml6nd73r000ep2vw9fy4v4x5	2026-02-03 13:41:23.127	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6nbucc0004p2vwguixqxss	\N	BOOKING_START	\N
cml6nuqkf000op2vwuduq3rxy	2026-02-03 13:55:01.504	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6nbucc0004p2vwguixqxss	\N	BOOKING_FINISH	\N
cml6qzer40001p2q03vfhu3gu	2026-02-03 15:22:38.32	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6nbucc0004p2vwguixqxss	\N	BOOKING_PHOTO_DELETE	{"url": "/uploads/bookings/cml6nbucc0004p2vwguixqxss/1770127539743_before.jpg", "kind": "BEFORE", "photoId": "cml6o8f1g0001p2gs4euurn7f"}
cml6ra21g0006p2q0k3h0txvx	2026-02-03 15:30:55.06	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lyjod000zp21kj6224s2i	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1500, "methodType": "CASH"}
cml6ra8470008p2q0748t1fy3	2026-02-03 15:31:02.935	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lyjod000zp21kj6224s2i	\N	BOOKING_START	\N
cml6rbzpv000ep2q0i7j2sgcu	2026-02-03 15:32:25.363	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lyjod000zp21kj6224s2i	\N	BOOKING_PHOTO_DELETE	{"url": "/uploads/bookings/cml6lyjod000zp21kj6224s2i/1770132697950_before.jpg", "kind": "BEFORE", "photoId": "cml6raz50000ap2q0zwqu8hln"}
cml6rcr21000ip2q0l6jtjksm	2026-02-03 15:33:00.793	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	cml6lyjod000zp21kj6224s2i	\N	BOOKING_FINISH	\N
cml932bgf000gp2lwtj9whg8o	2026-02-05 06:36:21.759	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml6j03hu0016p2lcd3uozc5g	\N	\N	SHIFT_CLOSE	\N
cml932dlc000kp2lwaodeextd	2026-02-05 06:36:24.528	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml932dl7000ip2lwhguezq28	\N	\N	SHIFT_OPEN	\N
cml9eme0x000gp24gc0bl37sz	2026-02-05 11:59:53.986	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml932dl7000ip2lwhguezq28	cml9el3h2000ap24gmayyolr6	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 2000, "methodType": "CASH"}
cml9emlir000kp24g47q2q8eq	2026-02-05 12:00:03.699	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml932dl7000ip2lwhguezq28	cml9d6vjd0004p24gd85ntfzz	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 700, "methodType": "CASH"}
cml9emnyl000mp24gzuyy79o0	2026-02-05 12:00:06.861	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml932dl7000ip2lwhguezq28	cml9d6vjd0004p24gd85ntfzz	\N	BOOKING_FINISH	\N
cml9g3vz00014p24gqpb9ndqu	2026-02-05 12:41:30.012	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml932dl7000ip2lwhguezq28	\N	\N	SHIFT_CLOSE	\N
cml9g3y320018p24gk2bhbafx	2026-02-05 12:41:32.75	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml9g3y2y0016p24gkuyrx064	\N	\N	SHIFT_OPEN	\N
cmlbvxnbq0001p2est2a3uiap	2026-02-07 05:40:05.078	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml9g3y2y0016p24gkuyrx064	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlbvxos20003p2esc45t2oux	2026-02-07 05:40:06.963	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml9g3y2y0016p24gkuyrx064	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlbw2vz5000ep2eshf8k68gb	2026-02-07 05:44:09.569	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cml9g3y2y0016p24gkuyrx064	\N	\N	SHIFT_CLOSE	\N
cmlbw67py000jp2esulf909au	2026-02-07 05:46:44.758	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	SHIFT_OPEN	\N
cmlbyyk2a000pp2eszlyib7i6	2026-02-07 07:04:46.354	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlbyykpw000rp2esbvemkuoy	2026-02-07 07:04:47.204	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlbz6pho000vp2esxdu11g6c	2026-02-07 07:11:06.637	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlbz6qpa000xp2esgvape16w	2026-02-07 07:11:08.206	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlbzlfik0010p2ese8yytncu	2026-02-07 07:22:33.549	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlbzlg5q0012p2es51el80fk	2026-02-07 07:22:34.382	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlc2xhdz0003p2lksbzsh50h	2026-02-07 08:55:54.695	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlc2xj240005p2lk7ex1l2cp	2026-02-07 08:55:56.86	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlc30mlj000cp2lkjs0u94cy	2026-02-07 08:58:21.415	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlc30n71000ep2lks49usrck	2026-02-07 08:58:22.19	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlc59m150001p2bcbet8w9tk	2026-02-07 10:01:19.817	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryz0003p20wh6f36n97", "prevStatus": "WAITING", "waitlistId": "cmkzj4b510007p2vwa1zk3t8e", "desiredBayId": 1, "desiredDateTime": "2026-02-02T05:00:00.000Z"}
cmlc5a2hq0003p2bc5gk9kniq	2026-02-07 10:01:41.151	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cml19fvir000ip25sowjfk6lb", "desiredBayId": null, "desiredDateTime": "2026-02-01T06:00:00.000Z"}
cmlcdldi0000yp2qc7y161wp6	2026-02-07 13:54:25.56	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcdkbjq000sp2qc5nyixdhd	\N	BOOKING_START	\N
cmlc5ac0l0005p2bc0c8wpx2n	2026-02-07 10:01:53.493	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cmkziyx6y0005p2vwaoay88y2", "desiredBayId": 1, "desiredDateTime": "2026-01-31T14:00:00.000Z"}
cmlc6fotq0008p2bczvnfdcjx	2026-02-07 10:34:02.991	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlc6fq4h000ap2bctkm3h28l	2026-02-07 10:34:04.674	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlcadrgx0002p2b87ng2d957	2026-02-07 12:24:31.569	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlcadrz50004p2b898b7aq80	2026-02-07 12:24:32.225	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlcaeb2s0008p2b82ija6uyt	2026-02-07 12:24:56.98	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmkxaco0000p2mkg7qvjdr3	WAITLIST_DELETE	{"carId": "cml3xm2xd0004p284yvvs1sh8", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cmlc6gah8000ep2bcz7mismqb", "desiredBayId": null, "desiredDateTime": "2026-02-07T11:00:00.000Z"}
cmlcaeldl000cp2b8iwfg92fo	2026-02-07 12:25:10.329	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcae4a10006p2b8hx1uyln8	cmkmkxaco0000p2mkg7qvjdr3	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1200, "methodType": "CASH"}
cmlcaeop3000ep2b87gkqz1sn	2026-02-07 12:25:14.632	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcae4a10006p2b8hx1uyln8	\N	BOOKING_START	\N
cmlcaf05h000gp2b8fye39f2g	2026-02-07 12:25:29.477	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcae4a10006p2b8hx1uyln8	\N	BOOKING_FINISH	\N
cmlcaft0r000jp2b8avzpquzq	2026-02-07 12:26:06.892	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlcafuh0000lp2b8ksj1pq4c	2026-02-07 12:26:08.772	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlcaj8ik000tp2b8damby88n	2026-02-07 12:28:46.94	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmlcagymn000sp2b81gdleeac", "desiredBayId": null, "desiredDateTime": "2026-02-07T13:00:00.000Z"}
cmlcdbdjq0001p2qcac6t1kjp	2026-02-07 13:46:39.062	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmkwtqopn000bp2wosrdexai7", "desiredBayId": 1, "desiredDateTime": "2026-01-27T18:00:00.000Z"}
cmlcdbf5j0002p2qcq9hqk3tp	2026-02-07 13:46:41.143	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmkwtqm8v0009p2woo6jj12xs", "desiredBayId": 1, "desiredDateTime": "2026-01-27T17:30:00.000Z"}
cmlcdbgvb0003p2qcrkn4ii3d	2026-02-07 13:46:43.367	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmkwtqh1n0007p2wo283lv20y", "desiredBayId": 2, "desiredDateTime": "2026-01-27T17:00:00.000Z"}
cmlcdbmiy0005p2qcr8kscq7w	2026-02-07 13:46:50.699	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cmlcagkq6000qp2b8x4vhs2oj", "desiredBayId": null, "desiredDateTime": "2026-02-07T13:00:00.000Z"}
cmlcdbpfd0007p2qcdt2w83l6	2026-02-07 13:46:54.457	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikrz10004p20wyvrm0oz1", "prevStatus": "WAITING", "waitlistId": "cmlcaolkt000vp2b8m3faod2v", "desiredBayId": null, "desiredDateTime": "2026-02-07T13:00:00.000Z"}
cmlcdbsdi0009p2qc11kbzprp	2026-02-07 13:46:58.279	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkmundtt0001p2lk2zc5xaxe	WAITLIST_DELETE	{"carId": "cmkz9385i0001p2x0uetvdk1h", "reason": "Клиент не отвечает", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cmlcagfvn000op2b8nvyskmfn", "desiredBayId": null, "desiredDateTime": "2026-02-07T13:00:00.000Z"}
cmlcdenzf000cp2qc8avsg4qo	2026-02-07 13:49:12.555	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmlcddmiq000bp2qcp77zx19l", "desiredBayId": 1, "desiredDateTime": "2026-02-07T14:00:00.000Z"}
cmlcdfscy000gp2qc1i7gcqut	2026-02-07 13:50:04.882	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlcdfuks000ip2qc431ubib5	2026-02-07 13:50:07.757	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlcdhami000kp2qc4afrfxu4	2026-02-07 13:51:15.211	WAITLIST_DELETE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_DELETE	{"carId": "cmkwnlhiu0014p2cg1rp6pmkm", "reason": "Клиент отменил", "newStatus": "CANCELED", "serviceId": "cmkmikryv0002p20wmdaa77vd", "prevStatus": "WAITING", "waitlistId": "cmlcdf5a1000ep2qcxditdem9", "desiredBayId": 1, "desiredDateTime": "2026-02-07T14:00:00.000Z"}
cmlcdie8b000op2qcef8f8b3m	2026-02-07 13:52:06.54	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlcdifo6000qp2qc5h4op6hd	2026-02-07 13:52:08.407	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlcdl8zg000wp2qc6k2k5qzz	2026-02-07 13:54:19.709	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcdkbjq000sp2qc5nyixdhd	cmkwnl6pz0012p2cg9njh1qrl	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1200, "methodType": "CASH"}
cmlcdm00d0010p2qcn34m1a47	2026-02-07 13:54:54.733	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	cmlcdkbjq000sp2qc5nyixdhd	\N	BOOKING_FINISH	\N
cmlce6u4s0001p2xsy38tc19f	2026-02-07 14:11:06.892	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlce6vrg0003p2xskq3tie7u	2026-02-07 14:11:09.004	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlce76xa0006p2xsjqepppi2	2026-02-07 14:11:23.471	BOOKING_DELETE	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	cmkwnl6pz0012p2cg9njh1qrl	WAITLIST_CLIENT_CANCEL	{"newStatus": "CANCELED", "prevStatus": "WAITING", "waitlistId": "cmlce6wqq0005p2xsqsk8ej3t", "desiredBayId": null, "desiredDateTime": "2026-02-07T14:30:00.000Z"}
cmlcfrutj000ep2xsgpuqhn4n	2026-02-07 14:55:27.175	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlbw67pu000hp2esquqocv5p	\N	\N	SHIFT_CLOSE	\N
cmlg7e5110003p2ccub06do3j	2026-02-10 06:11:54.997	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	SHIFT_OPEN	\N
cmlgll8d50008p2awny5i6muy	2026-02-10 12:49:20.538	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlgll920000ap2awrxkhyfhn	2026-02-10 12:49:21.432	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlglphn7000mp2aw95pt99n0	2026-02-10 12:52:39.187	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglky3c0004p2awu6qmv1yv	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 2800, "methodType": "CASH"}
cmlglpmis000op2aw82jm2mlf	2026-02-10 12:52:45.508	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglky3c0004p2awu6qmv1yv	\N	BOOKING_START	\N
cmlgluvhb0001p2247k8904hj	2026-02-10 12:56:50.399	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglky3c0004p2awu6qmv1yv	\N	BOOKING_FINISH	\N
cmlglv1910003p224vs6tfhg1	2026-02-10 12:56:57.878	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglnksw000cp2awm832vdp0	\N	BOOKING_START	\N
cmlglv5rn0007p224734gjcwl	2026-02-10 12:57:03.731	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglnksw000cp2awm832vdp0	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 4000, "methodType": "CASH"}
cmlglzpaq000hp224lpt53xyh	2026-02-10 13:00:35.667	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlglnksw000cp2awm832vdp0	\N	BOOKING_FINISH	\N
cmlgm48fv000rp224428g84g2	2026-02-10 13:04:07.1	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgly87c0009p224egm73l84	\N	BOOKING_START	\N
cmlgm4cme000tp224bldf7e75	2026-02-10 13:04:12.519	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgm0pwq000jp224zl1sf8pu	\N	BOOKING_START	\N
cmlgm4g2c000xp224z7qo7vwu	2026-02-10 13:04:16.98	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgly87c0009p224egm73l84	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 4000, "methodType": "CASH"}
cmlgm4t6i0011p224v1vijucr	2026-02-10 13:04:33.978	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgm0pwq000jp224zl1sf8pu	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 4000, "methodType": "CASH"}
cmlgm4xg20013p224j6eafsk6	2026-02-10 13:04:39.506	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgly87c0009p224egm73l84	\N	BOOKING_FINISH	\N
cmlgm4zlm0015p224p2ebgrwg	2026-02-10 13:04:42.298	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgm0pwq000jp224zl1sf8pu	\N	BOOKING_FINISH	\N
cmlgma8a10017p224zu4vu0h8	2026-02-10 13:08:46.825	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlgma9rx0019p224hc7fj497	2026-02-10 13:08:48.766	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlgmx6uy0003p2z0355715mz	2026-02-10 13:26:38.075	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgmbg50001bp224ougwkl4e	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 4000, "methodType": "CASH"}
cmlgmxgwz0005p2z04a3nj3pp	2026-02-10 13:26:51.107	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlgmxhks0007p2z0uac1gp7m	2026-02-10 13:26:51.964	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlgmxkdi0009p2z0todhybqg	2026-02-10 13:26:55.59	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgmbg50001bp224ougwkl4e	\N	BOOKING_START	\N
cmlgmxmed000bp2z07y45awam	2026-02-10 13:26:58.213	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgmbg50001bp224ougwkl4e	\N	BOOKING_FINISH	\N
cmlgmxvxj000dp2z0f0l72146	2026-02-10 13:27:10.568	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmlgmxx9w000fp2z0ruzu0wfw	2026-02-10 13:27:12.308	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmlgvmofr0008p25w9nk6pylb	2026-02-10 17:30:24.183	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgmz0sy000hp2z0sy7xz5w4	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 4000, "methodType": "CASH"}
cmlgvn5yh000ap25wtmdb8qun	2026-02-10 17:30:46.889	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmlgvn6k1000cp25wooeerrsv	2026-02-10 17:30:47.665	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmlgvp8q2000ip25wems52p9w	2026-02-10 17:32:23.786	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgvoeyp000ep25wa5ou5b64	cmlgn2eq40000p25wjgtzz6ep	PAYMENT_MARKED	{"kind": "REMAINING", "method": "CASH", "amountRub": 1200, "methodType": "CASH"}
cmlgvpb3v000kp25w23rkg5j6	2026-02-10 17:32:26.875	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	cmlgvoeyp000ep25wa5ou5b64	\N	BOOKING_START	\N
cmljkij9o0007p2u0hw0ki2ya	2026-02-12 14:42:33.612	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlg7e50h0001p2ccovneh02x	\N	\N	SHIFT_CLOSE	\N
cmljkim6y000bp2u01rha2v2o	2026-02-12 14:42:37.402	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	SHIFT_OPEN	\N
cmljkj17i000fp2u0skk3ah1i	2026-02-12 14:42:56.862	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 1}
cmljkj3bb000hp2u059tbhg6r	2026-02-12 14:42:59.591	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 1}
cmljkj5jf000jp2u07sqwwxh6	2026-02-12 14:43:02.475	BAY_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	Ремонт/тех.перерыв	{"isActive": false, "bayNumber": 2}
cmljkj6dz000lp2u0dpaezs09	2026-02-12 14:43:03.575	BAY_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	BAY_OPEN	{"isActive": true, "bayNumber": 2}
cmljkleqg000up2u0sxcexjly	2026-02-12 14:44:47.704	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	cmljkkvn6000qp2u0tvtpf11t	cmljkkvme000mp2u08bn5g9lu	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 1200, "methodType": "CASH"}
cmljklziu000wp2u0ncuhg2um	2026-02-12 14:45:14.646	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	cmljkkvn6000qp2u0tvtpf11t	\N	BOOKING_START	\N
cmljkm66e000yp2u0q3lnj0q1	2026-02-12 14:45:23.27	BOOKING_FINISH	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	cmljkkvn6000qp2u0tvtpf11t	\N	BOOKING_FINISH	\N
cmlp3pxzg0007p25wlmgc54r1	2026-02-16 11:39:02.861	SHIFT_CLOSE	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmljkim6n0009p2u081fzbb6x	\N	\N	SHIFT_CLOSE	\N
cmlp3q2op000bp25w6dds8h9i	2026-02-16 11:39:08.953	SHIFT_OPEN	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlp3q2ol0009p25wgn8s6d5s	\N	\N	SHIFT_OPEN	\N
cmlp3svzx000np25whdy4k18d	2026-02-16 11:41:20.253	PAYMENT_MARKED	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlp3q2ol0009p25wgn8s6d5s	cmlp3r3re000hp25wrlb8uqmk	cmlglky2v0000p2awdeh5unsr	Создано админом	{"kind": "REMAINING", "method": "CASH", "amountRub": 1700, "methodType": "CASH"}
cmlp3syig000pp25wy2vohb6m	2026-02-16 11:41:23.513	BOOKING_START	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	cmlp3q2ol0009p25wgn8s6d5s	cmlp3r3re000hp25wrlb8uqmk	\N	BOOKING_START	\N
\.


--
-- Data for Name: Bay; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Bay" (id, "createdAt", "updatedAt", "locationId", number, "isActive", "closedReason", "closedAt", "reopenedAt") FROM stdin;
cmknqksyq0003p2ok8v98zz34	2026-01-21 08:03:39.554	2026-02-16 15:49:54.851	cmkmikryn0000p20w74dgo9rk	1	t	\N	\N	2026-02-12 14:42:59.576
cmknqksyw0005p2okeebe9s08	2026-01-21 08:03:39.56	2026-02-16 15:49:54.853	cmkmikryn0000p20w74dgo9rk	2	t	\N	\N	2026-02-12 14:43:03.564
cmknqksz00007p2okrmqoddkr	2026-01-21 08:03:39.564	2026-02-16 15:49:54.855	cmkmikrys0001p20whl02brir	1	t	\N	\N	\N
cmknqksz30009p2oklw3y2ck6	2026-01-21 08:03:39.568	2026-02-16 15:49:54.856	cmkmikrys0001p20whl02brir	2	t	\N	\N	\N
\.


--
-- Data for Name: Booking; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Booking" (id, "createdAt", "updatedAt", "dateTime", "carId", "serviceId", status, "canceledAt", "cancelReason", "paymentDueAt", "bayId", "bufferMin", comment, "depositRub", "clientId", "locationId", "adminNote", "finishedAt", "shiftId", "startedAt", "discountNote", "discountRub", "requestedBayId") FROM stdin;
cml9gsj0t0004p290r2nk2ufz	2026-02-05 13:00:39.629	2026-02-05 13:01:12.342	2026-02-07 12:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	CANCELED	2026-02-05 13:01:12.339	USER_CANCELED_PENDING	2026-02-05 13:10:39.615	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml9el3h2000ap24gmayyolr6	2026-02-05 11:58:53.654	2026-02-05 15:07:03.83	2026-02-05 12:30:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml9g4glr001ip24g76pgxms5	2026-02-05 12:41:56.752	2026-02-06 10:00:00.074	2026-02-06 09:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmlbyzgzt000tp2esz3q2f8m8	2026-02-07 07:05:29.033	2026-02-07 09:00:23.979	2026-02-07 16:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	CANCELED	2026-02-07 09:00:23.977	USER_CANCELED	\N	1	15	sdasdadaadg	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlbw67pu000hp2esquqocv5p	\N	\N	0	\N
cml9gszo4000ap290hgexq2d0	2026-02-05 13:01:01.204	2026-02-07 09:00:31.296	2026-02-07 13:30:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	CANCELED	2026-02-07 09:00:31.294	USER_CANCELED	\N	2	15	dbsdgdfsdbxcb	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	2
cmlc13c8f0001p2lklhuze63k	2026-02-07 08:04:28.72	2026-02-07 09:00:36.882	2026-02-07 10:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	CANCELED	2026-02-07 09:00:36.88	USER_CANCELED	\N	2	15	\N	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlbw67pu000hp2esquqocv5p	\N	\N	0	\N
cmlc4bhtu000ip2lktxsqwjis	2026-02-07 09:34:48.067	2026-02-07 11:30:00.015	2026-02-07 10:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	вапрвапврар	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlbw67pu000hp2esquqocv5p	\N	\N	0	1
cmlcdkbjq000sp2qc5nyixdhd	2026-02-07 13:53:36.374	2026-02-07 13:54:54.727	2026-02-07 14:00:00	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	0	cmkwnl6pz0012p2cg9njh1qrl	cmkmikryn0000p20w74dgo9rk	\N	2026-02-07 13:54:54.723	cmlbw67pu000hp2esquqocv5p	2026-02-07 13:54:25.548	\N	0	\N
cmlgly87c0009p224egm73l84	2026-02-10 12:59:26.857	2026-02-10 13:04:39.502	2026-02-10 15:00:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-10 13:04:39.499	cmlg7e50h0001p2ccovneh02x	2026-02-10 13:04:07.09	\N	0	\N
cmlgmbg50001bp224ougwkl4e	2026-02-10 13:09:43.668	2026-02-10 13:26:58.21	2026-02-10 13:30:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-10 13:26:58.207	cmlg7e50h0001p2ccovneh02x	2026-02-10 13:26:55.582	\N	0	\N
cml6cvsrd000kp23w8zq5jm4e	2026-02-03 08:47:55.225	2026-02-03 09:14:04.217	2026-02-03 09:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	нет комментариев	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 09:14:04.214	cml3wl9ko000ep2f0sc1te96f	2026-02-03 08:50:21.941	\N	0	\N
cmlgvoeyp000ep25wa5ou5b64	2026-02-10 17:31:45.217	2026-02-10 23:07:45.622	2026-02-10 18:00:00	cmlgn2eqb0002p25wnv2hsxho	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	0	cmlgn2eq40000p25wjgtzz6ep	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlg7e50h0001p2ccovneh02x	2026-02-10 17:32:26.861	\N	0	1
cml6idjz9000mp2lco5wz8sm3	2026-02-03 11:21:41.733	2026-02-03 11:39:10.035	2026-02-03 12:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	CANCELED	2026-02-03 11:39:10.033	USER_CANCELED	\N	1	15	стекла изнутри не протирать	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cml3wl9ko000ep2f0sc1te96f	2026-02-03 11:21:49.949	\N	0	\N
cmlp3r3re000hp25wrlb8uqmk	2026-02-16 11:39:57.002	2026-02-16 13:00:00.013	2026-02-16 12:00:00	cmlp3r3r5000fp25w3vkodq11	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	\N	cmlp3q2ol0009p25wgn8s6d5s	2026-02-16 11:41:23.496	\N	0	\N
cml6lgfic0004p21kw7au9mfp	2026-02-03 12:47:54.756	2026-02-03 12:49:14.814	2026-02-04 06:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	окна внутри не мыть	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 12:49:14.811	cml6j03hu0016p2lcd3uozc5g	2026-02-03 12:48:29.901	\N	0	\N
cml6j1fe9001mp2lc6gvli0w9	2026-02-03 11:40:15.537	2026-02-03 12:55:06.069	2026-02-04 05:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 12:55:06.066	cml6j03hu0016p2lcd3uozc5g	2026-02-03 12:54:54.277	\N	0	\N
cml6nbucc0004p2vwguixqxss	2026-02-03 13:40:19.933	2026-02-03 13:55:01.499	2026-02-04 05:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	стекла внутри не мыть совсем	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 13:55:01.496	cml6j03hu0016p2lcd3uozc5g	2026-02-03 13:41:23.117	\N	0	\N
cml23470r001wp2fkrsi02m8i	2026-01-31 09:03:26.091	2026-02-05 06:19:00.061	2026-02-05 05:00:00	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	2	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml992qxw0003p2xs8sqqz2dw	2026-02-05 09:24:39.525	2026-02-05 11:00:00.021	2026-02-05 10:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	цукцукцуцукцукцукцкцу	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	1
cmkwnm1wb0018p2cgcuoaqkhk	2026-01-27 13:50:34.523	2026-01-27 15:57:32.874	2026-01-27 14:00:00	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	Коврики не надо	500	cmkwnl6pz0012p2cg9njh1qrl	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmkwtqw5u000fp2wowx0smrxb	2026-01-27 16:42:18.066	2026-01-29 07:29:00.657	2026-01-27 17:00:00	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkwnl6pz0012p2cg9njh1qrl	cmkmikrys0001p20whl02brir	\N	\N	\N	\N	\N	0	\N
cml9fp1d3000sp24gtl3jl4oi	2026-02-05 12:29:57.16	2026-02-05 18:00:00.031	2026-02-05 17:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	2	15	варвапрвапрвапрвапв	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	2
cml9q9sk30004p24sf4hss38k	2026-02-05 17:26:01.683	2026-02-05 19:00:00.017	2026-02-05 18:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	asdasfsadfsadfasd	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	1
cml9gj8c6001rp24g439cjakw	2026-02-05 12:53:25.879	2026-02-06 11:00:00.025	2026-02-06 10:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmlc31gr0000gp2lklnjq0uw5	2026-02-07 08:59:00.492	2026-02-07 09:00:11.162	2026-02-07 18:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	CANCELED	2026-02-07 09:00:11.16	USER_CANCELED	\N	1	15	вапрвапврар	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlbw67pu000hp2esquqocv5p	\N	\N	0	1
cmlbzlv830014p2esd5pme7zr	2026-02-07 07:22:53.907	2026-02-07 09:00:17.179	2026-02-10 05:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	CANCELED	2026-02-07 09:00:17.177	USER_CANCELED	\N	2	15	фвыфвыпфывфаывфывф	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	cmlbw67pu000hp2esquqocv5p	\N	\N	0	\N
cml9gkv4m001xp24gb713nobu	2026-02-05 12:54:42.071	2026-02-07 10:00:00.034	2026-02-07 09:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	2	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	2
cmlcae4a10006p2b8hx1uyln8	2026-02-07 12:24:48.169	2026-02-07 12:25:29.472	2026-02-07 12:30:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	вввввввввввв	0	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-07 12:25:29.469	cmlbw67pu000hp2esquqocv5p	2026-02-07 12:25:14.622	\N	0	\N
cml6ga6180005p2lcdnkf9li2	2026-02-03 10:23:04.46	2026-02-03 10:24:13.172	2026-02-03 11:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	машина в пленке	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 10:24:13.166	cml3wl9ko000ep2f0sc1te96f	2026-02-03 10:24:08.24	\N	0	\N
cmlglky3c0004p2awu6qmv1yv	2026-02-10 12:49:07.224	2026-02-10 12:56:50.394	2026-02-10 13:00:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	2	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-10 12:56:50.389	cmlg7e50h0001p2ccovneh02x	2026-02-10 12:52:45.494	\N	0	\N
cmlglnksw000cp2awm832vdp0	2026-02-10 12:51:09.969	2026-02-10 13:00:35.658	2026-02-10 13:00:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-10 13:00:35.654	cmlg7e50h0001p2ccovneh02x	2026-02-10 12:56:57.868	\N	0	\N
cmkza9jrh000rp2x0nftfy044	2026-01-29 10:00:14.669	2026-01-29 10:07:43.322	2026-01-30 05:00:00	cmkz9385i0001p2x0uetvdk1h	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	2026-01-29 10:07:43.318	cmkzac50q000zp2x0p4i25xhj	2026-01-29 10:05:29.332	\N	0	\N
cmkzaa4x0000xp2x0kjzq40kh	2026-01-29 10:00:42.084	2026-01-29 10:16:04.703	2026-01-30 06:30:00	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	CANCELED	2026-01-29 10:16:04.702	PAYMENT_EXPIRED	2026-01-29 10:10:42.074	2	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmlgm0pwq000jp224zl1sf8pu	2026-02-10 13:01:23.115	2026-02-10 13:04:42.294	2026-02-10 17:00:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-10 13:04:42.291	cmlg7e50h0001p2ccovneh02x	2026-02-10 13:04:12.511	\N	0	\N
cml6kzj9j0006p2eo1aomhp84	2026-02-03 12:34:46.471	2026-02-03 12:35:51.389	2026-02-04 09:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 12:35:51.383	cml6j03hu0016p2lcd3uozc5g	2026-02-03 12:35:07.366	\N	0	\N
cmkzgyqcb000fp2us74iyz434	2026-01-29 13:07:47.292	2026-01-29 14:03:38.025	2026-02-01 05:00:00	cmkz9385i0001p2x0uetvdk1h	cmkmikrz10004p20wyvrm0oz1	CANCELED	2026-01-29 14:03:38.019	PAYMENT_EXPIRED	2026-01-29 13:17:47.282	1	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml6j0qfd001ep2lc68ealmwb	2026-02-03 11:39:43.177	2026-02-03 12:55:19.409	2026-02-03 12:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	стекла изнутри не мыть	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 12:55:19.407	cml6j03hu0016p2lcd3uozc5g	2026-02-03 12:14:23.1	\N	0	\N
cmkzj4k13000fp2vw0e85z0zq	2026-01-29 14:08:18.28	2026-01-29 18:11:00.047	2026-02-02 05:00:00	cmkz9385i0001p2x0uetvdk1h	cmkmikryz0003p20wh6f36n97	CANCELED	2026-01-29 18:11:00.014	PAYMENT_EXPIRED	2026-01-29 14:18:18.263	1	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmlgmz0sy000hp2z0sy7xz5w4	2026-02-10 13:28:03.538	2026-02-10 17:30:00.022	2026-02-10 15:30:00	cmlglky350002p2aw389gtxrd	cmkmikryz0003p20wh6f36n97	COMPLETED	\N	\N	\N	1	15	\N	0	cmlglky2v0000p2awdeh5unsr	cmkmikryn0000p20w74dgo9rk	Создано админом	\N	\N	\N	\N	0	\N
cmkzgxv770009p2uspgaocfpg	2026-01-29 13:07:06.931	2026-01-29 18:44:28.84	2026-01-31 06:00:00	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	2026-01-29 18:44:28.836	cmkzkubyx000pp2vwarch23mp	2026-01-29 18:44:28.839	\N	0	\N
cmkzah0s80019p2x0mjyfcyjb	2026-01-29 10:06:03.32	2026-01-30 17:53:00.035	2026-01-30 08:30:00	cmkz9385i0001p2x0uetvdk1h	cmkmikrz10004p20wyvrm0oz1	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml6lyjod000zp21kj6224s2i	2026-02-03 13:01:59.965	2026-02-03 15:33:00.786	2026-02-05 09:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-03 15:33:00.78	cml6j03hu0016p2lcd3uozc5g	2026-02-03 15:31:02.924	\N	0	\N
cmljkkvn6000qp2u0tvtpf11t	2026-02-12 14:44:22.963	2026-02-12 14:45:23.258	2026-02-12 18:00:00	cmljkkvmt000op2u0q09homhz	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	0	cmljkkvme000mp2u08bn5g9lu	cmkmikryn0000p20w74dgo9rk	Создано админом	2026-02-12 14:45:23.25	cmljkim6n0009p2u081fzbb6x	2026-02-12 14:45:14.626	\N	0	\N
cml92q2qj0004p2lwihu8lgzv	2026-02-05 06:26:50.587	2026-02-05 08:00:00.059	2026-02-05 07:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	стекла внутри не мыть	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cmlw0133r0004p21c36m1a7xx	2026-02-21 07:30:07.479	2026-02-21 07:30:54.671	2026-02-21 08:00:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	ACTIVE	\N	\N	\N	1	15	арки не мыть	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	\N	\N	\N	\N	0	\N
cml9d6vjd0004p24gd85ntfzz	2026-02-05 11:19:50.57	2026-02-05 12:00:06.856	2026-02-05 11:30:00	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	COMPLETED	\N	\N	\N	1	15	\N	500	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	\N	2026-02-05 12:00:06.853	cml932dl7000ip2lwhguezq28	2026-02-05 12:00:06.855	\N	0	\N
\.


--
-- Data for Name: BookingAddon; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."BookingAddon" (id, "createdAt", "bookingId", "serviceId", qty, "priceRubSnapshot", "durationMinSnapshot", note, "updatedAt") FROM stdin;
cml23470y001yp2fksp5iqm2b	2026-01-31 09:03:26.098	cml23470r001wp2fkrsi02m8i	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-01-31 09:03:26.098
cml6cvss1000mp23wkmi7p273	2026-02-03 08:47:55.249	cml6cvsrd000kp23w8zq5jm4e	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 08:47:55.249
cml6ga61o0007p2lcusyaus51	2026-02-03 10:23:04.476	cml6ga6180005p2lcdnkf9li2	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 10:23:04.476
cml6idjzo000op2lcvs7wv629	2026-02-03 11:21:41.748	cml6idjz9000mp2lco5wz8sm3	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 11:21:41.748
cml6j0qfp001gp2lcpoxuhvyb	2026-02-03 11:39:43.189	cml6j0qfd001ep2lc68ealmwb	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 11:39:43.189
cml6j1feg001op2lcu8l8leot	2026-02-03 11:40:15.544	cml6j1fe9001mp2lc6gvli0w9	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 11:40:15.544
cml6kzj9v0008p2eovtltxhd2	2026-02-03 12:34:46.483	cml6kzj9j0006p2eo1aomhp84	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 12:34:46.483
cml6lgfip0006p21kiru3jkeq	2026-02-03 12:47:54.77	cml6lgfic0004p21kw7au9mfp	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 12:47:54.77
cml6lyjoq0011p21k0nnjgdij	2026-02-03 13:01:59.978	cml6lyjod000zp21kj6224s2i	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 13:01:59.978
cml6nbucn0006p2vwz8s4578q	2026-02-03 13:40:19.943	cml6nbucc0004p2vwguixqxss	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-03 13:40:19.943
cml92q2qx0006p2lwsmw6mmcc	2026-02-05 06:26:50.601	cml92q2qj0004p2lwihu8lgzv	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-05 06:26:50.601
cml992qy60005p2xsd7gtn70s	2026-02-05 09:24:39.535	cml992qxw0003p2xs8sqqz2dw	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-05 09:24:39.535
cml9fp1dg000up24gv33v25cv	2026-02-05 12:29:57.173	cml9fp1d3000sp24gtl3jl4oi	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-05 12:29:57.173
cml9gszoc000cp290vemwslze	2026-02-05 13:01:01.213	cml9gszo4000ap290hgexq2d0	cmkmikryz0003p20wh6f36n97	1	2500	60	\N	2026-02-05 13:01:01.213
cml9q9skg0006p24sl3rxq3ri	2026-02-05 17:26:01.697	cml9q9sk30004p24sf4hss38k	cmkmikrz10004p20wyvrm0oz1	1	800	15	\N	2026-02-05 17:26:01.697
cmlglky3h0006p2awlrvl3ex5	2026-02-10 12:49:07.229	cmlglky3c0004p2awu6qmv1yv	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 12:49:07.229
cmlglnksy000ep2aw1j9x09vd	2026-02-10 12:51:09.971	cmlglnksw000cp2awm832vdp0	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-10 12:51:09.971
cmlglnkt0000gp2awuuiqfv7y	2026-02-10 12:51:09.972	cmlglnksw000cp2awm832vdp0	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 12:51:09.972
cmlglnkt1000ip2aw5b1jmq1o	2026-02-10 12:51:09.973	cmlglnksw000cp2awm832vdp0	b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	1	700	15	\N	2026-02-10 12:51:09.973
cmlgly87e000bp22472lfy4lm	2026-02-10 12:59:26.859	cmlgly87c0009p224egm73l84	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-10 12:59:26.859
cmlgly87h000dp224wwfwxo51	2026-02-10 12:59:26.861	cmlgly87c0009p224egm73l84	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 12:59:26.861
cmlgly87i000fp224en4zgfdi	2026-02-10 12:59:26.862	cmlgly87c0009p224egm73l84	b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	1	700	15	\N	2026-02-10 12:59:26.862
cmlgm0pwt000lp2248g0odgob	2026-02-10 13:01:23.118	cmlgm0pwq000jp224zl1sf8pu	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-10 13:01:23.118
cmlgm0pwv000np224r4aopdhf	2026-02-10 13:01:23.12	cmlgm0pwq000jp224zl1sf8pu	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 13:01:23.12
cmlgm0pwx000pp224jxatulok	2026-02-10 13:01:23.121	cmlgm0pwq000jp224zl1sf8pu	b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	1	700	15	\N	2026-02-10 13:01:23.121
cmlgmbg53001dp224yjna1exb	2026-02-10 13:09:43.672	cmlgmbg50001bp224ougwkl4e	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-10 13:09:43.672
cmlgmbg56001fp224r0i4jfwt	2026-02-10 13:09:43.675	cmlgmbg50001bp224ougwkl4e	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 13:09:43.675
cmlgmbg58001hp224ikh4o48m	2026-02-10 13:09:43.676	cmlgmbg50001bp224ougwkl4e	b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	1	700	15	\N	2026-02-10 13:09:43.676
cmlgmz0t0000jp2z0q3mmxh1a	2026-02-10 13:28:03.541	cmlgmz0sy000hp2z0sy7xz5w4	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-10 13:28:03.541
cmlgmz0t2000lp2z08udwdmrh	2026-02-10 13:28:03.543	cmlgmz0sy000hp2z0sy7xz5w4	32642703-eff0-4e68-bca6-7956005270b5	1	300	15	\N	2026-02-10 13:28:03.543
cmlgmz0t4000np2z0cyq836fg	2026-02-10 13:28:03.544	cmlgmz0sy000hp2z0sy7xz5w4	b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	1	700	15	\N	2026-02-10 13:28:03.544
cmlp3r3ro000jp25wmx4nhgl0	2026-02-16 11:39:57.013	cmlp3r3re000hp25wrlb8uqmk	3174d935-d33e-48a3-b3b1-01827f51984a	1	500	15	\N	2026-02-16 11:39:57.013
cmlw013440006p21c47p30aea	2026-02-21 07:30:07.492	cmlw0133r0004p21c36m1a7xx	cmlpcok6o000tp244nw5mqpgg	1	300	10	\N	2026-02-21 07:30:07.492
\.


--
-- Data for Name: BookingPhoto; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."BookingPhoto" (id, "createdAt", "bookingId", kind, url, note, "uploadedByUserId") FROM stdin;
cml6ndfy4000gp2vwve13ztny	2026-02-03 13:41:34.588	cml6nbucc0004p2vwguixqxss	BEFORE	/uploads/bookings/cml6nbucc0004p2vwguixqxss/1770126094582_before.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6ngt2t000ip2vwxprtcpj3	2026-02-03 13:44:11.574	cml6nbucc0004p2vwguixqxss	BEFORE	/uploads/bookings/cml6nbucc0004p2vwguixqxss/1770126251568_before.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6ntirm000kp2vwgtimxhsr	2026-02-03 13:54:04.738	cml6nbucc0004p2vwguixqxss	AFTER	/uploads/bookings/cml6nbucc0004p2vwguixqxss/1770126844734_after.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6nu2t4000mp2vwuwp3h6da	2026-02-03 13:54:30.712	cml6nbucc0004p2vwguixqxss	DAMAGE	/uploads/bookings/cml6nbucc0004p2vwguixqxss/1770126870708_damage.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6rb73v000cp2q0vnkdb5fd	2026-02-03 15:31:48.283	cml6lyjod000zp21kj6224s2i	AFTER	/uploads/bookings/cml6lyjod000zp21kj6224s2i/1770132708279_after.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6rc4sq000gp2q0p4wcevc1	2026-02-03 15:32:31.947	cml6lyjod000zp21kj6224s2i	AFTER	/uploads/bookings/cml6lyjod000zp21kj6224s2i/1770132751942_after.jpg	\N	cmkmikrz80008p20wut6ot34m
cml6rd0rb000kp2q0hljbopxx	2026-02-03 15:33:13.368	cml6lyjod000zp21kj6224s2i	AFTER	/uploads/bookings/cml6lyjod000zp21kj6224s2i/1770132793361_after.jpg	\N	cmkmikrz80008p20wut6ot34m
cml9t79t5000ap24s9mxh4fbv	2026-02-05 18:48:02.921	cml9q9sk30004p24sf4hss38k	BEFORE	/uploads/bookings/cml9q9sk30004p24sf4hss38k/1770317282918_before.jpg	\N	cmkmikrz80008p20wut6ot34m
cml9t7fqm000cp24ste2komhf	2026-02-05 18:48:10.606	cml9q9sk30004p24sf4hss38k	AFTER	/uploads/bookings/cml9q9sk30004p24sf4hss38k/1770317290602_after.jpg	\N	cmkmikrz80008p20wut6ot34m
\.


--
-- Data for Name: Car; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Car" (id, "createdAt", "updatedAt", "makeDisplay", "modelDisplay", "plateDisplay", "makeNormalized", "modelNormalized", "plateNormalized", year, color, "bodyType", "clientId") FROM stdin;
cmkmymxgt0007p2mgbt49xam4	2026-01-20 19:01:29.454	2026-01-20 19:01:29.454	MERCEDES	—	А111АА	MERCEDES	—	А111АА	\N	\N	SEDAN	cmkmymo9o0005p2mgn2nluao6
cmkwnlhiu0014p2cg1rp6pmkm	2026-01-27 13:50:08.118	2026-01-27 13:50:08.118	BMW	—	В111ВВ977	BMW	—	В111ВВ977	\N	\N	SUV	cmkwnl6pz0012p2cg9njh1qrl
cmkz9385i0001p2x0uetvdk1h	2026-01-29 09:27:20.071	2026-01-29 09:27:20.071	MERCEDES	—	А132АА	MERCEDES	—	А132АА	\N	\N	SEDAN	cmkmundtt0001p2lk2zc5xaxe
cml3xm2xd0004p284yvvs1sh8	2026-02-01 16:04:55.25	2026-02-01 16:04:55.25	BMW	—	А434ЕА	BMW	—	А434ЕА	\N	\N	SUV	cmkmkxaco0000p2mkg7qvjdr3
cmlglky350002p2aw389gtxrd	2026-02-10 12:49:07.218	2026-02-10 12:49:07.218	—	—	х165еу	—	—	Х165ЕУ	\N	\N	SEDAN	cmlglky2v0000p2awdeh5unsr
cmlgn2eqb0002p25wnv2hsxho	2026-02-10 13:30:41.556	2026-02-10 13:30:41.556	—	—	х651еу	—	—	Х651ЕУ	\N	\N	SUV	cmlgn2eq40000p25wjgtzz6ep
cmljkkvmt000op2u0q09homhz	2026-02-12 14:44:22.95	2026-02-12 14:44:22.95	—	—	а456аа	—	—	А456АА	\N	\N	HATCH	cmljkkvme000mp2u08bn5g9lu
cmlp3r3r5000fp25w3vkodq11	2026-02-16 11:39:56.994	2026-02-16 11:39:56.994	—	—	х165еу977	—	—	Х165ЕУ977	\N	\N	SEDAN	cmlglky2v0000p2awdeh5unsr
\.


--
-- Data for Name: Client; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Client" (id, "createdAt", "updatedAt", phone, name, gender, "birthDate", "blockReason", "blockedAt", "blockedByUserId", "isBlocked") FROM stdin;
cmkmymo9o0005p2mgn2nluao6	2026-01-20 19:01:17.52	2026-01-20 19:01:17.52	+777999999999	Кирилл	MALE	2001-01-19 21:00:00	\N	\N	\N	f
cmkwnl6pz0012p2cg9njh1qrl	2026-01-27 13:49:54.119	2026-02-07 13:45:26.536	+779999994567	Роман	MALE	\N	\N	\N	\N	f
cmlglky2v0000p2awdeh5unsr	2026-02-10 12:49:07.207	2026-02-10 13:28:03.518	+79273109336	Роман Ларионов	\N	\N	\N	\N	\N	f
cmlgn2eq40000p25wjgtzz6ep	2026-02-10 13:30:41.549	2026-02-10 13:30:41.549	+79273109999	Антон Петров	\N	\N	\N	\N	\N	f
cmljkkvme000mp2u08bn5g9lu	2026-02-12 14:44:22.934	2026-02-12 14:44:22.934	927333666	Роман	\N	\N	\N	\N	\N	f
cmkmundtt0001p2lk2zc5xaxe	2026-01-20 17:09:52.194	2026-02-12 14:47:31.616	+779997774567	Роман	MALE	\N	\N	\N	\N	f
cmkmkxaco0000p2mkg7qvjdr3	2026-01-20 12:37:38.087	2026-02-21 07:20:28.502	+779991234567	Роман	MALE	\N	\N	\N	\N	f
\.


--
-- Data for Name: ClientLocation; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."ClientLocation" (id, "createdAt", "updatedAt", "clientId", "locationId", "isBlocked", "blockReason", "blockedAt", "blockedByUserId", "lastVisitAt") FROM stdin;
cmkpic24v000rp2r8x3i8lj2x	2026-01-22 13:48:26.959	2026-01-31 09:03:26.086	cmkmundtt0001p2lk2zc5xaxe	cmkmikryn0000p20w74dgo9rk	f	\N	\N	\N	2026-01-31 09:03:26.085
cmkwnm1vz0016p2cgtqwdtyhs	2026-01-27 13:50:34.512	2026-01-27 13:50:34.512	cmkwnl6pz0012p2cg9njh1qrl	cmkmikryn0000p20w74dgo9rk	f	\N	\N	\N	2026-01-27 13:50:34.504
cmkwtqw5h000dp2woxry8rb9z	2026-01-27 16:42:18.054	2026-01-27 16:42:18.054	cmkwnl6pz0012p2cg9njh1qrl	cmkmikrys0001p20whl02brir	f	\N	\N	\N	2026-01-27 16:42:18.051
cmknvdsfy0002p2ewbwbww8nm	2026-01-21 10:18:10.367	2026-02-21 07:30:07.467	cmkmkxaco0000p2mkg7qvjdr3	cmkmikryn0000p20w74dgo9rk	f	\N	\N	\N	2026-02-21 07:30:07.464
\.


--
-- Data for Name: Location; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Location" (id, "createdAt", "updatedAt", name, address, "colorHex", "baysCount", "tenantId") FROM stdin;
cmkmikryn0000p20w74dgo9rk	2026-01-20 11:31:55.152	2026-02-16 15:49:54.847	Мойка #1	Локация 1 (заменить позже)	#2D9CDB	2	demo-tenant
cmkmikrys0001p20whl02brir	2026-01-20 11:31:55.156	2026-02-16 15:49:54.85	Мойка #2	Локация 2 (заменить позже)	#2DBD6E	2	demo-tenant
\.


--
-- Data for Name: Payment; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Payment" (id, "createdAt", "paidAt", "amountRub", method, kind, "bookingId", "methodType") FROM stdin;
cml6cvxfj000op23w821hj41x	2026-02-03 08:48:01.279	2026-02-03 08:48:01.278	500	CARD_TEST	DEPOSIT	cml6cvsrd000kp23w8zq5jm4e	CARD
cml6cyu3t000qp23wax0p5lcj	2026-02-03 08:50:16.937	2026-02-03 08:50:16.936	2800	CASH	REMAINING	cml6cvsrd000kp23w8zq5jm4e	CASH
cml6ga9gv0009p2lcuptzqzam	2026-02-03 10:23:08.911	2026-02-03 10:23:08.91	500	CARD_TEST	DEPOSIT	cml6ga6180005p2lcdnkf9li2	CARD
cml6gbfg5000bp2lchqdp75di	2026-02-03 10:24:03.317	2026-02-03 10:24:03.316	2800	CASH	REMAINING	cml6ga6180005p2lcdnkf9li2	CASH
cml6idlfd000qp2lcnohf47x1	2026-02-03 11:21:43.61	2026-02-03 11:21:43.609	500	CARD_TEST	DEPOSIT	cml6idjz9000mp2lco5wz8sm3	CARD
cml6idzd1000up2lctgowl3hw	2026-02-03 11:22:01.669	2026-02-03 11:22:01.668	2800	CARD	REMAINING	cml6idjz9000mp2lco5wz8sm3	CARD
cml6j0syb001ip2lcuyalplcd	2026-02-03 11:39:46.451	2026-02-03 11:39:46.449	500	CARD_TEST	DEPOSIT	cml6j0qfd001ep2lc68ealmwb	CARD
cml6j1kmq001qp2lc6uu8tx4x	2026-02-03 11:40:22.322	2026-02-03 11:40:22.321	500	CARD_TEST	DEPOSIT	cml6j1fe9001mp2lc6gvli0w9	CARD
cml6kzlfr000ap2eossm8t33l	2026-02-03 12:34:49.287	2026-02-03 12:34:49.286	500	CARD_TEST	DEPOSIT	cml6kzj9j0006p2eo1aomhp84	CARD
cml6l0b9a000ep2eocgd4za3w	2026-02-03 12:35:22.75	2026-02-03 12:35:22.748	2800	CASH	REMAINING	cml6kzj9j0006p2eo1aomhp84	CASH
cml6lggo40008p21kv11re3a4	2026-02-03 12:47:56.261	2026-02-03 12:47:56.26	500	CARD_TEST	DEPOSIT	cml6lgfic0004p21kw7au9mfp	CARD
cml6lhfut000cp21kwemrxood	2026-02-03 12:48:41.861	2026-02-03 12:48:41.859	2800	CASH	REMAINING	cml6lgfic0004p21kw7au9mfp	CASH
cml6lpk93000kp21kasht4d1c	2026-02-03 12:55:00.808	2026-02-03 12:55:00.807	1500	CASH	REMAINING	cml6j1fe9001mp2lc6gvli0w9	CASH
cml6lpw1s000qp21kl47qdz7r	2026-02-03 12:55:16.096	2026-02-03 12:55:16.096	2800	CASH	REMAINING	cml6j0qfd001ep2lc68ealmwb	CASH
cml6lykum0013p21kyfxqwu22	2026-02-03 13:02:01.486	2026-02-03 13:02:01.48	500	CARD_TEST	DEPOSIT	cml6lyjod000zp21kj6224s2i	CARD
cml6nbvu90008p2vwepmhleco	2026-02-03 13:40:21.874	2026-02-03 13:40:21.872	500	CARD_TEST	DEPOSIT	cml6nbucc0004p2vwguixqxss	CARD
cml6nd1sz000ap2vwp0l177c5	2026-02-03 13:41:16.259	2026-02-03 13:41:16.258	2800	CASH	REMAINING	cml6nbucc0004p2vwguixqxss	CASH
cml6ra21b0004p2q07h2rkrb4	2026-02-03 15:30:55.055	2026-02-03 15:30:55.054	1500	CASH	REMAINING	cml6lyjod000zp21kj6224s2i	CASH
cml92q3vv0008p2lwr3qzj0jr	2026-02-05 06:26:52.075	2026-02-05 06:26:52.073	500	CARD_TEST	DEPOSIT	cml92q2qj0004p2lwihu8lgzv	CARD
cmkwnm33j001ap2cgf2f1jsmf	2026-01-27 13:50:36.079	2026-01-27 13:50:36.072	500	CARD_TEST	DEPOSIT	cmkwnm1wb0018p2cgcuoaqkhk	CARD
cml992s2s0007p2xsgestkef7	2026-02-05 09:24:40.997	2026-02-05 09:24:40.996	500	CARD_TEST	DEPOSIT	cml992qxw0003p2xs8sqqz2dw	CARD
cmkwtqx3a000hp2wojyesgm9q	2026-01-27 16:42:19.27	2026-01-27 16:42:19.268	500	CARD_TEST	DEPOSIT	cmkwtqw5u000fp2wowx0smrxb	CARD
cml9d6wrd0006p24gudgb8nua	2026-02-05 11:19:52.154	2026-02-05 11:19:52.15	500	CARD_TEST	DEPOSIT	cml9d6vjd0004p24gd85ntfzz	CARD
cml9el7ra000cp24gq2nzvr4f	2026-02-05 11:58:59.207	2026-02-05 11:58:59.206	500	CARD_TEST	DEPOSIT	cml9el3h2000ap24gmayyolr6	CARD
cml9eme0t000ep24gsfoxds22	2026-02-05 11:59:53.982	2026-02-05 11:59:53.981	2000	CASH	REMAINING	cml9el3h2000ap24gmayyolr6	CASH
cml9emlim000ip24gqtseoiid	2026-02-05 12:00:03.694	2026-02-05 12:00:03.693	700	CASH	REMAINING	cml9d6vjd0004p24gd85ntfzz	CASH
cml9fp2ja000wp24gjkbb1vix	2026-02-05 12:29:58.678	2026-02-05 12:29:58.677	500	CARD_TEST	DEPOSIT	cml9fp1d3000sp24gtl3jl4oi	CARD
cml9g5r2c001kp24gw1w5zgya	2026-02-05 12:42:56.964	2026-02-05 12:42:56.963	500	CARD_TEST	DEPOSIT	cml9g4glr001ip24g76pgxms5	CARD
cml9gj9nr001tp24g6bph47jn	2026-02-05 12:53:27.592	2026-02-05 12:53:27.59	500	CARD_TEST	DEPOSIT	cml9gj8c6001rp24g439cjakw	CARD
cmkza9l64000tp2x0r6cwddms	2026-01-29 10:00:16.492	2026-01-29 10:00:16.49	500	CARD_TEST	DEPOSIT	cmkza9jrh000rp2x0nftfy044	CARD
cmkzah9u9001bp2x0htyqy6ny	2026-01-29 10:06:15.057	2026-01-29 10:06:15.056	500	CARD_TEST	DEPOSIT	cmkzah0s80019p2x0mjyfcyjb	CARD
cmkzaisk9001dp2x08na2w1he	2026-01-29 10:07:25.977	2026-01-29 10:07:25.976	2000	CASH	REMAINING	cmkza9jrh000rp2x0nftfy044	CASH
cmkzgxw9l000bp2ustgpq7yel	2026-01-29 13:07:08.313	2026-01-29 13:07:08.312	500	CARD_TEST	DEPOSIT	cmkzgxv770009p2uspgaocfpg	CARD
cml9gkw7c001zp24gmyanxppn	2026-02-05 12:54:43.464	2026-02-05 12:54:43.464	500	CARD_TEST	DEPOSIT	cml9gkv4m001xp24gb713nobu	CARD
cml9gt3ks000ep290wmmzysae	2026-02-05 13:01:06.268	2026-02-05 13:01:06.266	500	CARD_TEST	DEPOSIT	cml9gszo4000ap290hgexq2d0	CARD
cml9q9u8a0008p24s08hhmjfh	2026-02-05 17:26:03.85	2026-02-05 17:26:03.848	500	CARD_TEST	DEPOSIT	cml9q9sk30004p24sf4hss38k	CARD
cmlcaeldh000ap2b8ar4434wt	2026-02-07 12:25:10.326	2026-02-07 12:25:10.325	1200	CASH	REMAINING	cmlcae4a10006p2b8hx1uyln8	CASH
cml2348020020p2fkdunkoz9c	2026-01-31 09:03:27.362	2026-01-31 09:03:27.361	500	CARD_TEST	DEPOSIT	cml23470r001wp2fkrsi02m8i	CARD
cmlcdl8zc000up2qcr3zlo6p2	2026-02-07 13:54:19.705	2026-02-07 13:54:19.703	1200	CASH	REMAINING	cmlcdkbjq000sp2qc5nyixdhd	CASH
cmlglphn0000kp2awdg11y3mb	2026-02-10 12:52:39.18	2026-02-10 12:52:39.179	2800	CASH	REMAINING	cmlglky3c0004p2awu6qmv1yv	CASH
cmlglv5ri0005p224mb2gsjcy	2026-02-10 12:57:03.726	2026-02-10 12:57:03.725	4000	CASH	REMAINING	cmlglnksw000cp2awm832vdp0	CASH
cmlgm4g26000vp2247pdnf4bn	2026-02-10 13:04:16.975	2026-02-10 13:04:16.974	4000	CASH	REMAINING	cmlgly87c0009p224egm73l84	CASH
cmlgm4t6d000zp224drr0ug1s	2026-02-10 13:04:33.974	2026-02-10 13:04:33.973	4000	CASH	REMAINING	cmlgm0pwq000jp224zl1sf8pu	CASH
cmlgmx6ut0001p2z03z1zdaqa	2026-02-10 13:26:38.069	2026-02-10 13:26:38.068	4000	CASH	REMAINING	cmlgmbg50001bp224ougwkl4e	CASH
cmlgvmofn0006p25wn0pg8wa5	2026-02-10 17:30:24.18	2026-02-10 17:30:24.179	4000	CASH	REMAINING	cmlgmz0sy000hp2z0sy7xz5w4	CASH
cmlgvp8pw000gp25wygn16ha8	2026-02-10 17:32:23.781	2026-02-10 17:32:23.779	1200	CASH	REMAINING	cmlgvoeyp000ep25wa5ou5b64	CASH
cmljkleq4000sp2u0we6tj728	2026-02-12 14:44:47.692	2026-02-12 14:44:47.691	1200	CASH	REMAINING	cmljkkvn6000qp2u0tvtpf11t	CASH
cmlp3svzs000lp25w3vpa2l1b	2026-02-16 11:41:20.248	2026-02-16 11:41:20.245	1700	CASH	REMAINING	cmlp3r3re000hp25wrlb8uqmk	CASH
cmlw023ii0008p21c9kwhp517	2026-02-21 07:30:54.666	2026-02-21 07:30:54.664	500	CARD_TEST	DEPOSIT	cmlw0133r0004p21c36m1a7xx	CARD
\.


--
-- Data for Name: PlannedShift; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."PlannedShift" (id, "createdAt", "updatedAt", "locationId", "createdByUserId", "startAt", "endAt", status, note) FROM stdin;
cmlqv2f4w0001p24w9krnot33	2026-02-17 17:12:20.768	2026-02-17 18:17:30.408	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-18 05:00:00	2026-02-18 17:00:00	PUBLISHED	Дневная смена
cmlqmsk2j0001p20g6sklgde3	2026-02-17 13:20:43.676	2026-02-17 18:21:27.135	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-18 07:00:00	2026-02-18 19:00:00	CANCELED	??????? ?????
cmlqv3h2e0003p24w4om0n3r2	2026-02-17 17:13:09.927	2026-02-17 18:25:38.643	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-18 05:00:00	2026-02-18 17:00:00	CANCELED	Дневная смена
cmlqxeso3000bp24wwhdhsrzx	2026-02-17 18:17:57.411	2026-02-17 18:27:34.349	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-18 05:00:00	2026-02-18 17:00:00	CANCELED	Дневная смена
\.


--
-- Data for Name: PlannedShiftWasher; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."PlannedShiftWasher" (id, "createdAt", "updatedAt", "plannedShiftId", "washerId", "plannedBayId", note) FROM stdin;
cmlqx1ra80005p24wjwexz6hz	2026-02-17 18:07:49.088	2026-02-17 18:07:49.088	cmlqv2f4w0001p24w9krnot33	cmlpcok7a001lp244hh10z8p5	1	\N
cmlqxdoot0009p24w8ak2xowg	2026-02-17 18:17:05.597	2026-02-17 18:17:05.597	cmlqv3h2e0003p24w4om0n3r2	cmlpcok7a001lp244hh10z8p5	1	\N
cmlqxf39m000dp24we1tdvwjo	2026-02-17 18:18:11.146	2026-02-17 18:18:11.146	cmlqxeso3000bp24wwhdhsrzx	cmlpcok7a001lp244hh10z8p5	2	\N
\.


--
-- Data for Name: Service; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Service" (id, "createdAt", "updatedAt", name, "priceRub", "durationMin", "isActive", kind, "locationId", "sortOrder", "laborCategory") FROM stdin;
3174d935-d33e-48a3-b3b1-01827f51984a	2026-02-10 12:14:44.964	2026-02-10 12:14:44.964	Чернение шин	500	15	t	ADDON	cmkmikryn0000p20w74dgo9rk	110	WASH
32642703-eff0-4e68-bca6-7956005270b5	2026-02-10 12:14:44.964	2026-02-10 12:14:44.964	Помыть коврики	300	15	t	ADDON	cmkmikryn0000p20w74dgo9rk	120	WASH
b29bca24-1ae1-49d2-b9ad-c9ca05b6baff	2026-02-10 12:14:44.964	2026-02-10 12:14:44.964	Кондиционер кожи	700	15	t	ADDON	cmkmikryn0000p20w74dgo9rk	130	WASH
cmkmikryv0002p20wmdaa77vd	2026-01-20 11:31:55.16	2026-02-16 15:49:54.858	Мойка кузова	1200	30	t	BASE	cmkmikryn0000p20w74dgo9rk	10	WASH
cmkmikryz0003p20wh6f36n97	2026-01-20 11:31:55.163	2026-02-16 15:49:54.861	Комплекс	2500	60	t	BASE	cmkmikryn0000p20w74dgo9rk	20	WASH
cmkmikrz10004p20wyvrm0oz1	2026-01-20 11:31:55.166	2026-02-16 15:49:54.862	Воск	800	15	t	ADDON	cmkmikryn0000p20w74dgo9rk	110	WASH
cmlpcok6o000tp244nw5mqpgg	2026-02-16 15:49:54.864	2026-02-16 15:49:54.864	Коврики	300	10	t	ADDON	cmkmikryn0000p20w74dgo9rk	120	WASH
cmlpcok6q000vp244rxxnrz0w	2026-02-16 15:49:54.866	2026-02-16 15:49:54.866	Чернение резины	400	10	t	ADDON	cmkmikryn0000p20w74dgo9rk	130	WASH
cmlpcok6r000xp244c1057m29	2026-02-16 15:49:54.868	2026-02-16 15:49:54.868	Мойка кузова	1000	30	t	BASE	cmkmikrys0001p20whl02brir	10	WASH
f26609b9-253e-4659-8c45-c003c38e8d48	2026-02-10 09:41:57.228	2026-02-16 15:49:54.869	Комплекс	2300	60	t	BASE	cmkmikrys0001p20whl02brir	20	WASH
cmlpcok6u0011p2445ndhx87d	2026-02-16 15:49:54.87	2026-02-16 15:49:54.87	Салон	1500	30	t	BASE	cmkmikrys0001p20whl02brir	30	WASH
cmlpcok6v0013p244nuqwtd5f	2026-02-16 15:49:54.872	2026-02-16 15:49:54.872	Воск	700	15	t	ADDON	cmkmikrys0001p20whl02brir	110	WASH
cmlpcok6x0015p244n0pz02fr	2026-02-16 15:49:54.873	2026-02-16 15:49:54.873	Полировка	2000	30	t	ADDON	cmkmikrys0001p20whl02brir	120	WASH
\.


--
-- Data for Name: Shift; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Shift" (id, "createdAt", "locationId", "adminId", "openedAt", "closedAt", status, "plannedShiftId") FROM stdin;
cmknw3fwq0001p2fgxi97qmhf	2026-01-21 10:38:07.178	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-21 10:38:07.177	2026-01-21 11:01:00.05	CLOSED	\N
cmknx3fqq0004p2j8uxfsjaue	2026-01-21 11:06:06.578	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-21 11:06:06.576	2026-01-21 11:07:35.072	CLOSED	\N
cmknyniw60001p2u40eyl53t8	2026-01-21 11:49:43.398	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-21 11:49:43.397	2026-01-21 11:50:48.627	CLOSED	\N
cmknyp33e000bp2u47hhrjs9a	2026-01-21 11:50:56.234	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-21 11:50:56.233	2026-01-21 11:54:38.923	CLOSED	\N
cmknyu174000np2u409u0ga9g	2026-01-21 11:54:47.056	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-21 11:54:47.056	2026-01-21 12:05:34.154	CLOSED	\N
cmkpbsiec0001p2hwb3ncd27k	2026-01-22 10:45:17.219	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 10:45:17.218	2026-01-22 10:45:43.716	CLOSED	\N
cmkpc8kpv001cp2hwde2cb78j	2026-01-22 10:57:46.723	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 10:57:46.722	2026-01-22 10:59:14.752	CLOSED	\N
cmkpi9mak0001p2r8ws7b6upn	2026-01-22 13:46:33.116	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 13:46:33.115	2026-01-22 13:46:49.617	CLOSED	\N
cmkpifybc000xp2r8h7u0torl	2026-01-22 13:51:28.633	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 13:51:28.631	2026-01-22 13:57:35.181	CLOSED	\N
cmkpj7h92001jp2r8xdw0vcxv	2026-01-22 14:12:52.886	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 14:12:52.885	2026-01-22 15:17:25.521	CLOSED	\N
cmkpm7195000jp2nc7kkxbsbo	2026-01-22 15:36:31.001	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 15:36:31	2026-01-22 15:37:30.605	CLOSED	\N
cmkpnaoca0011p2ncigt4t3ow	2026-01-22 16:07:20.507	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 16:07:20.499	2026-01-22 16:59:37.627	CLOSED	\N
cmkpp61fx0009p20o9u1bfssf	2026-01-22 16:59:43.437	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-22 16:59:43.436	2026-01-25 11:58:21.674	CLOSED	\N
cmktoqp8u000yp2xgbr5yphlh	2026-01-25 11:58:52.495	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-25 11:58:52.493	2026-01-25 15:57:19.969	CLOSED	\N
cmktxawpg000qp20s1x1673ae	2026-01-25 15:58:32.212	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-25 15:58:32.21	2026-01-27 09:56:29.874	CLOSED	\N
cmkwfangy0009p2h0mde3w2ej	2026-01-27 09:57:45.683	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 09:57:45.682	2026-01-27 10:16:13.332	CLOSED	\N
cmkwfyick000np2h0b41mb93x	2026-01-27 10:16:18.789	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 10:16:18.787	2026-01-27 10:34:17.258	CLOSED	\N
cmkwgnf6a0019p2h0elstr25j	2026-01-27 10:35:41.074	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 10:35:41.073	2026-01-27 10:37:13.543	CLOSED	\N
cmkwgplj1001np2h0jqz46k84	2026-01-27 10:37:22.621	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 10:37:22.62	2026-01-27 10:40:15.954	CLOSED	\N
cmkwgzjk80027p2h07slf52sv	2026-01-27 10:45:06.632	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 10:45:06.631	2026-01-27 10:50:59.956	CLOSED	\N
cmkwh76jv002lp2h075pu3waa	2026-01-27 10:51:03.019	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 10:51:03.018	2026-01-27 12:14:50.55	CLOSED	\N
cmkwkgrii0009p2wkhm9ghj5d	2026-01-27 12:22:28.938	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 12:22:28.937	2026-01-27 13:41:50.404	CLOSED	\N
cmkwnax2v000jp2cg6kboq12k	2026-01-27 13:41:55.063	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 13:41:55.062	2026-01-27 13:44:44.688	CLOSED	\N
cmkwnm9r5001cp2cgba3cj8y6	2026-01-27 13:50:44.705	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 13:50:44.699	2026-01-27 15:51:33.704	CLOSED	\N
cmkwrxphf0009p2a8vo7zzyvz	2026-01-27 15:51:36.771	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-27 15:51:36.768	2026-01-29 07:37:03.896	CLOSED	\N
cmkz5aqvv000lp26ghyy2x5qh	2026-01-29 07:41:12.475	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 07:41:12.474	2026-01-29 07:43:14.954	CLOSED	\N
cmkz5kif5001dp26gfgh0tj6v	2026-01-29 07:48:48.065	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 07:48:48.064	2026-01-29 08:11:59.4	CLOSED	\N
cmkz6yyq00021p26gj0hyauv6	2026-01-29 08:28:01.993	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 08:28:01.991	2026-01-29 09:28:18.111	CLOSED	\N
cmkz9lzjh000bp2x0wuylm0vs	2026-01-29 09:41:55.373	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 09:41:55.372	2026-01-29 09:58:17.83	CLOSED	\N
cmkzac50q000zp2x0p4i25xhj	2026-01-29 10:02:15.53	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 10:02:15.529	2026-01-29 10:17:21.205	CLOSED	\N
cmkzgww1c0001p2us1trus4ky	2026-01-29 13:06:21.36	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 13:06:21.358	2026-01-29 14:55:35.327	CLOSED	\N
cmkzkubyx000pp2vwarch23mp	2026-01-29 14:56:20.506	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-29 14:56:20.504	2026-01-30 18:21:00.769	CLOSED	\N
cml182bh10006p2psuqbugxws	2026-01-30 18:34:10.454	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-01-30 18:34:10.452	2026-01-31 15:26:56.203	CLOSED	\N
cml3wl9ko000ep2f0sc1te96f	2026-02-01 15:36:17.592	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-01 15:36:17.591	2026-02-03 11:39:03.364	CLOSED	\N
cml6j03hu0016p2lcd3uozc5g	2026-02-03 11:39:13.458	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-03 11:39:13.457	2026-02-05 06:36:21.755	CLOSED	\N
cml932dl7000ip2lwhguezq28	2026-02-05 06:36:24.523	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-05 06:36:24.522	2026-02-05 12:41:30.004	CLOSED	\N
cml9g3y2y0016p24gkuyrx064	2026-02-05 12:41:32.746	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-05 12:41:32.744	2026-02-07 05:44:09.564	CLOSED	\N
cmlbw67pu000hp2esquqocv5p	2026-02-07 05:46:44.754	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-07 05:46:44.752	2026-02-07 14:55:27.169	CLOSED	\N
cmlg7e50h0001p2ccovneh02x	2026-02-10 06:11:54.978	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-10 06:11:54.976	2026-02-12 14:42:33.604	CLOSED	\N
cmljkim6n0009p2u081fzbb6x	2026-02-12 14:42:37.391	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-12 14:42:37.39	2026-02-16 11:39:02.854	CLOSED	\N
cmlp3q2ol0009p25wgn8s6d5s	2026-02-16 11:39:08.95	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	2026-02-16 11:39:08.949	\N	OPEN	\N
\.


--
-- Data for Name: ShiftCashEvent; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."ShiftCashEvent" (id, "createdAt", "shiftId", "locationId", "adminId", type, "amountRub", note) FROM stdin;
cmkpbspl50005p2hwk94d3gh2	2026-01-22 10:45:26.537	cmkpbsiec0001p2hwb3ncd27k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	200	Open float
cmkpbt2t60007p2hws67psbfs	2026-01-22 10:45:43.674	cmkpbsiec0001p2hwb3ncd27k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	200	\N
cmkpbt2ta0009p2hw8rm1dl0v	2026-01-22 10:45:43.678	cmkpbsiec0001p2hwb3ncd27k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkpbt2te000bp2hw8cl26fj9	2026-01-22 10:45:43.682	cmkpbsiec0001p2hwb3ncd27k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	200	\N
cmkpc8ops001gp2hwh5lvk6kq	2026-01-22 10:57:51.904	cmkpc8kpv001cp2hwde2cb78j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	100	Open float
cmkpcagmb001up2hwa8nn00nu	2026-01-22 10:59:14.724	cmkpc8kpv001cp2hwde2cb78j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	100	\N
cmkpcagmf001wp2hwf8od2yjt	2026-01-22 10:59:14.727	cmkpc8kpv001cp2hwde2cb78j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkpcagmh001yp2hwyh21gbbi	2026-01-22 10:59:14.729	cmkpc8kpv001cp2hwde2cb78j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	100	\N
cmkpi9r4p0005p2r8ycp0zfrn	2026-01-22 13:46:39.385	cmkpi9mak0001p2r8ws7b6upn	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	100	Размен/остаток на начало
cmkpi9z090007p2r83n6cv8ny	2026-01-22 13:46:49.593	cmkpi9mak0001p2r8ws7b6upn	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	100	\N
cmkpi9z0c0009p2r887vdojud	2026-01-22 13:46:49.597	cmkpi9mak0001p2r8ws7b6upn	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkpi9z0e000bp2r863xmp9oy	2026-01-22 13:46:49.598	cmkpi9mak0001p2r8ws7b6upn	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	100	\N
cmkpig8pf0011p2r85qsb4yyo	2026-01-22 13:51:42.099	cmkpifybc000xp2r8h7u0torl	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	100	Размен/остаток на начало
cmkpint4l001bp2r81lfc1551	2026-01-22 13:57:35.157	cmkpifybc000xp2r8h7u0torl	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	100	sdgsdfgsdfgsdfgsdfgs
cmkpint4o001dp2r8hprnw6tr	2026-01-22 13:57:35.16	cmkpifybc000xp2r8h7u0torl	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	50	sdgsdfgsdfgsdfgsdfgs
cmkpint4p001fp2r8dri6tcvb	2026-01-22 13:57:35.162	cmkpifybc000xp2r8h7u0torl	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	50	sdgsdfgsdfgsdfgsdfgs
cmkpj7ljh001np2r8sq7eqjr4	2026-01-22 14:12:58.445	cmkpj7h92001jp2r8xdw0vcxv	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	200	Размен/остаток на начало
cmkpm76ck000np2ncyzqw3m56	2026-01-22 15:36:37.604	cmkpm7195000jp2nc7kkxbsbo	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	1000	Размен/остаток на начало
cmkpm8b82000tp2nc9y6zlamy	2026-01-22 15:37:30.578	cmkpm7195000jp2nc7kkxbsbo	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	1000	вапыпывапывапыва
cmkpm8b85000vp2ncqxupwhos	2026-01-22 15:37:30.581	cmkpm7195000jp2nc7kkxbsbo	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	500	вапыпывапывапыва
cmkpm8b87000xp2ncj1jh986o	2026-01-22 15:37:30.583	cmkpm7195000jp2nc7kkxbsbo	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	500	вапыпывапывапыва
cmkpp5wxu0001p20o7o6c7wip	2026-01-22 16:59:37.602	cmkpnaoca0011p2ncigt4t3ow	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkpp5wxy0003p20ohknks2n4	2026-01-22 16:59:37.606	cmkpnaoca0011p2ncigt4t3ow	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkpp5wy00005p20oxqea07gh	2026-01-22 16:59:37.608	cmkpnaoca0011p2ncigt4t3ow	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkpp640q000dp20orpx702q8	2026-01-22 16:59:46.778	cmkpp61fx0009p20o9u1bfssf	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmktoq1ga000qp2xgn0a30t86	2026-01-25 11:58:21.658	cmkpp61fx0009p20o9u1bfssf	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	2000	\N
cmktoq1gc000sp2xgjfm2dexg	2026-01-25 11:58:21.661	cmkpp61fx0009p20o9u1bfssf	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmktoq1ge000up2xgaxc1t49c	2026-01-25 11:58:21.662	cmkpp61fx0009p20o9u1bfssf	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2000	\N
cmktoqze80012p2xgmqlf9dej	2026-01-25 11:59:05.648	cmktoqp8u000yp2xgbr5yphlh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	2500	Размен/остаток на начало
cmktx9cxx000ip20sjuf9h3ex	2026-01-25 15:57:19.942	cmktoqp8u000yp2xgbr5yphlh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	5700	\N
cmktx9cy0000kp20sfb1gtwiu	2026-01-25 15:57:19.944	cmktoqp8u000yp2xgbr5yphlh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	5000	\N
cmktx9cy1000mp20s3jqbb1gk	2026-01-25 15:57:19.945	cmktoqp8u000yp2xgbr5yphlh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	700	\N
cmktxb1kc000up20s9bufaexc	2026-01-25 15:58:38.508	cmktxawpg000qp20s1x1673ae	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	5000	Размен/остаток на начало
cmkwf90yk0001p2h0ibtom3qb	2026-01-27 09:56:29.853	cmktxawpg000qp20s1x1673ae	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	6700	\N
cmkwf90yq0003p2h0zve72vpu	2026-01-27 09:56:29.859	cmktxawpg000qp20s1x1673ae	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwf90ys0005p2h0nyu1jhrv	2026-01-27 09:56:29.86	cmktxawpg000qp20s1x1673ae	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	6700	\N
cmkwfartj000dp2h0sqy4wgl2	2026-01-27 09:57:51.319	cmkwfangy0009p2h0mde3w2ej	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	6000	Размен/остаток на начало
cmkwfye3z000fp2h03ie1al1s	2026-01-27 10:16:13.296	cmkwfangy0009p2h0mde3w2ej	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	6000	\N
cmkwfye43000hp2h0bga62q83	2026-01-27 10:16:13.299	cmkwfangy0009p2h0mde3w2ej	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwfye45000jp2h02hube0hc	2026-01-27 10:16:13.302	cmkwfangy0009p2h0mde3w2ej	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	6000	\N
cmkwfyk06000rp2h0qz5p39yz	2026-01-27 10:16:20.934	cmkwfyick000np2h0b41mb93x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkwglmhl0011p2h0aiseki8h	2026-01-27 10:34:17.241	cmkwfyick000np2h0b41mb93x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkwglmho0013p2h0e89yxmb2	2026-01-27 10:34:17.244	cmkwfyick000np2h0b41mb93x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwglmhp0015p2h0fy16y40b	2026-01-27 10:34:17.246	cmkwfyick000np2h0b41mb93x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkwgo05j001dp2h0homygclt	2026-01-27 10:36:08.263	cmkwgnf6a0019p2h0elstr25j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	5000	Размен/остаток на начало
cmkwgpei3001fp2h0bgljfmsd	2026-01-27 10:37:13.515	cmkwgnf6a0019p2h0elstr25j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	5000	хорошая смена
cmkwgpei5001hp2h0zbdy4xlz	2026-01-27 10:37:13.517	cmkwgnf6a0019p2h0elstr25j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	2500	хорошая смена
cmkwgpei6001jp2h0air4kxt8	2026-01-27 10:37:13.518	cmkwgnf6a0019p2h0elstr25j	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2500	хорошая смена
cmkwgpoid001rp2h0zw6jl8jf	2026-01-27 10:37:26.485	cmkwgplj1001np2h0jqz46k84	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	1000	Размен/остаток на начало
cmkwgtb99001zp2h0lrrx4xtu	2026-01-27 10:40:15.934	cmkwgplj1001np2h0jqz46k84	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	1000	\N
cmkwgtb9c0021p2h08czat6xa	2026-01-27 10:40:15.936	cmkwgplj1001np2h0jqz46k84	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwgtb9d0023p2h0gjmpo6un	2026-01-27 10:40:15.938	cmkwgplj1001np2h0jqz46k84	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	1000	\N
cmkwgzkz7002bp2h0yqrks63g	2026-01-27 10:45:08.468	cmkwgzjk80027p2h07slf52sv	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkwh7466002dp2h07dr0d40z	2026-01-27 10:50:59.935	cmkwgzjk80027p2h07slf52sv	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkwh7468002fp2h0wiuj44gc	2026-01-27 10:50:59.937	cmkwgzjk80027p2h07slf52sv	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwh746a002hp2h0i50d0dov	2026-01-27 10:50:59.938	cmkwgzjk80027p2h07slf52sv	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkwh77l1002pp2h07qq4fbgj	2026-01-27 10:51:04.357	cmkwh76jv002lp2h075pu3waa	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkwk6xsy0001p2wk0o2sbir4	2026-01-27 12:14:50.53	cmkwh76jv002lp2h075pu3waa	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkwk6xt10003p2wk9a668gup	2026-01-27 12:14:50.534	cmkwh76jv002lp2h075pu3waa	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwk6xt30005p2wki4m3b63r	2026-01-27 12:14:50.535	cmkwh76jv002lp2h075pu3waa	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkwkgsye000dp2wkc7syvf6e	2026-01-27 12:22:30.806	cmkwkgrii0009p2wkhm9ghj5d	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkwnatgt000bp2cgljb0g9me	2026-01-27 13:41:50.381	cmkwkgrii0009p2wkhm9ghj5d	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	2000	\N
cmkwnatgw000dp2cgu4mveom8	2026-01-27 13:41:50.384	cmkwkgrii0009p2wkhm9ghj5d	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwnatgx000fp2cgteb8em0p	2026-01-27 13:41:50.386	cmkwkgrii0009p2wkhm9ghj5d	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2000	\N
cmkwnay8x000np2cgc1zcna2o	2026-01-27 13:41:56.577	cmkwnax2v000jp2cg6kboq12k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkwnejxy000tp2cgpwc2fvon	2026-01-27 13:44:44.662	cmkwnax2v000jp2cg6kboq12k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkwnejy1000vp2cgmq96jhub	2026-01-27 13:44:44.665	cmkwnax2v000jp2cg6kboq12k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwnejy3000xp2cgjbefnmuc	2026-01-27 13:44:44.667	cmkwnax2v000jp2cg6kboq12k	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkwnmdlr001gp2cg2i7wglu1	2026-01-27 13:50:49.695	cmkwnm9r5001cp2cgba3cj8y6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	3000	Размен/остаток на начало
cmkwrxn3j0001p2a8rr6smrll	2026-01-27 15:51:33.678	cmkwnm9r5001cp2cgba3cj8y6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	3000	\N
cmkwrxn3n0003p2a8kd6bhluj	2026-01-27 15:51:33.683	cmkwnm9r5001cp2cgba3cj8y6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkwrxn3p0005p2a8m8s0428h	2026-01-27 15:51:33.685	cmkwnm9r5001cp2cgba3cj8y6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	3000	\N
cmkwrxqil000dp2a8r3dbyd51	2026-01-27 15:51:38.109	cmkwrxphf0009p2a8vo7zzyvz	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkz55f240007p26gtu1or8ex	2026-01-29 07:37:03.868	cmkwrxphf0009p2a8vo7zzyvz	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	2000	\N
cmkz55f290009p26gi4zt45tz	2026-01-29 07:37:03.873	cmkwrxphf0009p2a8vo7zzyvz	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkz55f2b000bp26gi6jv97bn	2026-01-29 07:37:03.875	cmkwrxphf0009p2a8vo7zzyvz	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2000	\N
cmkz5atkf000pp26gti0m07xf	2026-01-29 07:41:15.952	cmkz5aqvv000lp26ghyy2x5qh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	100	Размен/остаток на начало
cmkz5dddj000zp26gwznun544	2026-01-29 07:43:14.936	cmkz5aqvv000lp26ghyy2x5qh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	800	\N
cmkz5dddm0011p26gk3a1cvl5	2026-01-29 07:43:14.938	cmkz5aqvv000lp26ghyy2x5qh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkz5dddn0013p26gqvha1rui	2026-01-29 07:43:14.94	cmkz5aqvv000lp26ghyy2x5qh	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	800	\N
cmkz5kllc001hp26gfqoywws9	2026-01-29 07:48:52.176	cmkz5kif5001dp26gfgh0tj6v	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
cmkz6ebyr001tp26gwdomf32f	2026-01-29 08:11:59.38	cmkz5kif5001dp26gfgh0tj6v	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	500	\N
cmkz6ebyu001vp26g1gi3oykf	2026-01-29 08:11:59.382	cmkz5kif5001dp26gfgh0tj6v	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkz6ebyv001xp26gg32qbu6u	2026-01-29 08:11:59.384	cmkz5kif5001dp26gfgh0tj6v	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	500	\N
cmkz6z3uu0025p26gupnrwlyt	2026-01-29 08:28:08.647	cmkz6yyq00021p26gj0hyauv6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	900	Размен/остаток на начало
cmkz94gx90003p2x0w7m10lyd	2026-01-29 09:28:18.093	cmkz6yyq00021p26gj0hyauv6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	900	\N
cmkz94gxb0005p2x06ro6h0z9	2026-01-29 09:28:18.095	cmkz6yyq00021p26gj0hyauv6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkz94gxc0007p2x026tav0sd	2026-01-29 09:28:18.097	cmkz6yyq00021p26gj0hyauv6	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	900	\N
cmkz9m0o5000fp2x0aasjiiq2	2026-01-29 09:41:56.837	cmkz9lzjh000bp2x0wuylm0vs	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmkza71le000hp2x0eopegd3b	2026-01-29 09:58:17.81	cmkz9lzjh000bp2x0wuylm0vs	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmkza71lg000jp2x08trgwl0v	2026-01-29 09:58:17.812	cmkz9lzjh000bp2x0wuylm0vs	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkza71lh000lp2x0h4tu3w4v	2026-01-29 09:58:17.814	cmkz9lzjh000bp2x0wuylm0vs	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmkzac87u0013p2x0sno79hgk	2026-01-29 10:02:19.675	cmkzac50q000zp2x0p4i25xhj	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
cmkzavjtl001jp2x0vs6x1lme	2026-01-29 10:17:21.178	cmkzac50q000zp2x0p4i25xhj	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	2500	\N
cmkzavjto001lp2x0ejaav639	2026-01-29 10:17:21.181	cmkzac50q000zp2x0p4i25xhj	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	500	\N
cmkzavjtq001np2x030s7wvv4	2026-01-29 10:17:21.182	cmkzac50q000zp2x0p4i25xhj	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2000	\N
cmkzgwzzz0005p2us7lr42aq9	2026-01-29 13:06:26.495	cmkzgww1c0001p2us1trus4ky	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
cmkzktd34000hp2vwz9bf37s1	2026-01-29 14:55:35.296	cmkzgww1c0001p2us1trus4ky	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	500	\N
cmkzktd39000jp2vwa0ncw2cb	2026-01-29 14:55:35.302	cmkzgww1c0001p2us1trus4ky	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmkzktd3b000lp2vw6t8ua1tl	2026-01-29 14:55:35.303	cmkzgww1c0001p2us1trus4ky	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	500	\N
cmkzkufjo000tp2vwiwgr0tjb	2026-01-29 14:56:25.14	cmkzkubyx000pp2vwarch23mp	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
cml17le4r0001p2iwx2scx3bl	2026-01-30 18:21:00.748	cmkzkubyx000pp2vwarch23mp	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	500	\N
cml17le4w0003p2iwt5ok3egf	2026-01-30 18:21:00.752	cmkzkubyx000pp2vwarch23mp	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cml17le4y0005p2iwtax1vt23	2026-01-30 18:21:00.755	cmkzkubyx000pp2vwarch23mp	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	500	\N
cml182cj4000ap2psanyjs93b	2026-01-30 18:34:11.825	cml182bh10006p2psuqbugxws	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cml2gtdpt000xp2040ovgmtxg	2026-01-31 15:26:56.177	cml182bh10006p2psuqbugxws	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	6000	\N
cml2gtdpz000zp204u3yd6qvm	2026-01-31 15:26:56.183	cml182bh10006p2psuqbugxws	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	6000	\N
cml2gtdq10011p204y9wvjx00	2026-01-31 15:26:56.186	cml182bh10006p2psuqbugxws	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cml3wladr000ip2f0957wyag9	2026-02-01 15:36:18.639	cml3wl9ko000ep2f0sc1te96f	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cml6izvoq000yp2lcershktfh	2026-02-03 11:39:03.339	cml3wl9ko000ep2f0sc1te96f	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	5600	\N
cml6izvov0010p2lcjuem8ci0	2026-02-03 11:39:03.344	cml3wl9ko000ep2f0sc1te96f	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cml6izvox0012p2lcsfgvzbog	2026-02-03 11:39:03.345	cml3wl9ko000ep2f0sc1te96f	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	5600	\N
cml6j04g5001ap2lc38og9tvo	2026-02-03 11:39:14.693	cml6j03hu0016p2lcd3uozc5g	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cml932bfn000ap2lwvbhifdgx	2026-02-05 06:36:21.732	cml6j03hu0016p2lcd3uozc5g	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	14200	\N
cml932bfq000cp2lwrxfh7510	2026-02-05 06:36:21.735	cml6j03hu0016p2lcd3uozc5g	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cml932bft000ep2lwm7v80dw4	2026-02-05 06:36:21.737	cml6j03hu0016p2lcd3uozc5g	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	14200	\N
cml932emx000mp2lwrq4mxwrv	2026-02-05 06:36:25.881	cml932dl7000ip2lwhguezq28	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cml9g3vy3000yp24g00dscrf2	2026-02-05 12:41:29.979	cml932dl7000ip2lwhguezq28	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	700	\N
cml9g3vy50010p24gdfr23c1c	2026-02-05 12:41:29.982	cml932dl7000ip2lwhguezq28	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cml9g3vy70012p24gjqv1nn7o	2026-02-05 12:41:29.983	cml932dl7000ip2lwhguezq28	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	700	\N
cml9g3z98001ap24gcfbunlel	2026-02-05 12:41:34.269	cml9g3y2y0016p24gkuyrx064	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmlbw2vyi0008p2esdc5lk0ya	2026-02-07 05:44:09.547	cml9g3y2y0016p24gkuyrx064	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	0	\N
cmlbw2vyk000ap2es9ugx4ywz	2026-02-07 05:44:09.549	cml9g3y2y0016p24gkuyrx064	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	0	\N
cmlbw2vym000cp2esw2auly47	2026-02-07 05:44:09.55	cml9g3y2y0016p24gkuyrx064	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	0	\N
cmlbw69a4000lp2es7hr3rxr5	2026-02-07 05:46:46.781	cmlbw67pu000hp2esquqocv5p	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmlcfrusq0008p2xs5sjd4wzu	2026-02-07 14:55:27.146	cmlbw67pu000hp2esquqocv5p	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	2400	\N
cmlcfrust000ap2xsi4tj853l	2026-02-07 14:55:27.15	cmlbw67pu000hp2esquqocv5p	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	400	\N
cmlcfrusv000cp2xs28n68ji1	2026-02-07 14:55:27.152	cmlbw67pu000hp2esquqocv5p	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	2000	\N
cmlg7e6720005p2ccqsybhu41	2026-02-10 06:11:56.51	cmlg7e50h0001p2ccovneh02x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	0	Размен/остаток на начало
cmljkij8d0001p2u01niakx2m	2026-02-12 14:42:33.565	cmlg7e50h0001p2ccovneh02x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	20000	\N
cmljkij8i0003p2u0iysfqss5	2026-02-12 14:42:33.57	cmlg7e50h0001p2ccovneh02x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	15000	\N
cmljkij8l0005p2u0krg80lxt	2026-02-12 14:42:33.573	cmlg7e50h0001p2ccovneh02x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	5000	\N
cmljkis63000dp2u038i9q9fh	2026-02-12 14:42:45.147	cmljkim6n0009p2u081fzbb6x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
cmlp3pxyg0001p25w1kobgwxj	2026-02-16 11:39:02.825	cmljkim6n0009p2u081fzbb6x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	CLOSE_COUNT	1700	\N
cmlp3pxyo0003p25w8oiiohxh	2026-02-16 11:39:02.832	cmljkim6n0009p2u081fzbb6x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	HANDOVER	1500	\N
cmlp3pxyq0005p25wivyiho8a	2026-02-16 11:39:02.834	cmljkim6n0009p2u081fzbb6x	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	KEEP_IN_DRAWER	200	\N
cmlp3q6pt000dp25ws649feqb	2026-02-16 11:39:14.178	cmlp3q2ol0009p25wgn8s6d5s	cmkmikryn0000p20w74dgo9rk	cmkmikrz80008p20wut6ot34m	OPEN_FLOAT	500	Размен/остаток на начало
\.


--
-- Data for Name: ShiftWasher; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."ShiftWasher" (id, "createdAt", "updatedAt", "shiftId", "washerId", "bayId", "percentWash", "percentChem", "clockInAt", "clockOutAt") FROM stdin;
cmlphg94u0001p2o8p04s1y01	2026-02-16 18:03:25.375	2026-02-16 18:14:29.616	cmlp3q2ol0009p25wgn8s6d5s	cmlpcok7a001lp244hh10z8p5	1	30	40	2026-02-16 18:14:24.132	2026-02-16 18:14:29.613
\.


--
-- Data for Name: Tenant; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."Tenant" (id, "createdAt", "updatedAt", name, "isActive") FROM stdin;
demo-tenant	2026-01-22 12:28:31.451	2026-02-16 15:49:54.834	Demo Tenant	t
\.


--
-- Data for Name: TenantFeature; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."TenantFeature" (id, "createdAt", "updatedAt", "tenantId", key, enabled, params) FROM stdin;
2ab5f319-4dac-4b78-8be9-8b54def72a2a	2026-01-31 12:23:22.268	2026-01-31 12:23:22.268	demo-tenant	CONTACTS	t	{"phone": "+7-900-000-00-00", "title": "Контакты", "address": "Москва, ...", "telegram": "@carwash_demo", "whatsapp": "+7-900-000-00-00", "navigatorLink": "https://www.google.com/maps/search/?api=1&query=..."}
cmkpflufd0001p2ngreipe5l0	2026-01-22 12:32:04.681	2026-02-16 15:49:54.84	demo-tenant	CASH_DRAWER	t	\N
cmkpflufg0003p2ngjo2q2ht2	2026-01-22 12:32:04.684	2026-02-16 15:49:54.842	demo-tenant	BOOKING_MOVE	t	\N
cmkpflufi0005p2ng75cn7pk3	2026-01-22 12:32:04.686	2026-02-16 15:49:54.843	demo-tenant	CONTRACT_PAYMENTS	t	\N
cmkpflufj0007p2ng5gh9qs33	2026-01-22 12:32:04.688	2026-02-16 15:49:54.845	demo-tenant	DISCOUNTS	t	\N
cmkpflufl0009p2ng61q0u0z0	2026-01-22 12:32:04.689	2026-02-16 15:49:54.846	demo-tenant	MEDIA_PHOTOS	t	\N
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."User" (id, "createdAt", "updatedAt", phone, name, role, "isActive", "locationId", "shiftOpenAt", "shiftCloseAt") FROM stdin;
cmkmikrz50006p20wd5t2zd0g	2026-01-20 11:31:55.169	2026-02-16 15:49:54.881	+79990000001	Owner Demo	OWNER	t	cmkmikryn0000p20w74dgo9rk	\N	\N
cmkmikrz80008p20wut6ot34m	2026-01-20 11:31:55.172	2026-02-16 15:49:54.883	+79990000011	Admin 1 Demo	ADMIN	t	cmkmikryn0000p20w74dgo9rk	2026-02-16 11:39:08.949	\N
cmkmikrza000ap20wmzvumn9q	2026-01-20 11:31:55.174	2026-02-16 15:49:54.885	+79990000022	Admin 2 Demo	ADMIN	t	cmkmikrys0001p20whl02brir	\N	\N
cmlpcok7a001lp244hh10z8p5	2026-02-16 15:49:54.886	2026-02-16 15:49:54.886	+79990000101	Washer 1 Demo	WASHER	t	cmkmikryn0000p20w74dgo9rk	\N	\N
cmlpcok7c001np244f84v26kw	2026-02-16 15:49:54.888	2026-02-16 15:49:54.888	+79990000102	Washer 2 Demo	WASHER	t	cmkmikryn0000p20w74dgo9rk	\N	\N
\.


--
-- Data for Name: WaitlistRequest; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."WaitlistRequest" (id, "createdAt", "updatedAt", status, "locationId", "desiredDateTime", "desiredBayId", "clientId", "carId", "serviceId", comment, reason, "invitedAt", "convertedBookingId") FROM stdin;
cmlbyseiz000np2escilz7xrs	2026-02-07 06:59:59.244	2026-02-07 07:05:29.048	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 08:00:00	\N	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	sdasdadaadg	ALL_BAYS_CLOSED	2026-02-07 07:05:29.047	cmlbyzgzt000tp2esz3q2f8m8
cmlbvy4kd0006p2es2vcc01l6	2026-02-07 05:40:27.421	2026-02-07 07:22:53.916	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 06:00:00	\N	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	фвыфвыпфывфаывфывф	ALL_BAYS_CLOSED	2026-02-07 07:22:53.915	cmlbzlv830014p2esd5pme7zr
cml3y35c90008p284cg14vv22	2026-02-01 16:18:11.529	2026-02-07 08:04:28.732	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-01 16:30:00	\N	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	\N	ALL_BAYS_CLOSED	2026-02-07 08:04:28.731	cmlc13c8f0001p2lklhuze63k
cmlc2zwk60008p2lkuh23iafv	2026-02-07 08:57:47.67	2026-02-07 08:59:00.508	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 09:30:00	1	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	вапрвапврар	ALL_BAYS_CLOSED	2026-02-07 08:59:00.501	cmlc31gr0000gp2lklnjq0uw5
cmlc305bk000ap2lkeymprhiv	2026-02-07 08:57:59.024	2026-02-07 09:34:48.075	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 09:30:00	1	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryz0003p20wh6f36n97	вапрвапврар	ALL_BAYS_CLOSED	2026-02-07 09:34:48.074	cmlc4bhtu000ip2lktxsqwjis
cmkzj4b510007p2vwa1zk3t8e	2026-01-29 14:08:06.757	2026-02-07 10:01:19.811	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-02 05:00:00	1	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryz0003p20wh6f36n97	\N	ADMIN_DELETED: Клиент не отвечает	\N	\N
cml19fvir000ip25sowjfk6lb	2026-01-30 19:12:42.579	2026-02-07 10:01:41.147	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-01 06:00:00	\N	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	\N	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmkziyx6y0005p2vwaoay88y2	2026-01-29 14:03:55.402	2026-02-07 10:01:53.489	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-01-31 14:00:00	1	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	\N	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmlc6g27s000cp2bcni32gyhh	2026-02-07 10:34:20.345	2026-02-07 12:24:48.18	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 11:00:00	\N	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	вввввввввввв	ALL_BAYS_CLOSED	2026-02-07 12:24:48.179	cmlcae4a10006p2b8hx1uyln8
cmlc6gah8000ep2bcz7mismqb	2026-02-07 10:34:31.053	2026-02-07 12:24:56.977	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 11:00:00	\N	cmkmkxaco0000p2mkg7qvjdr3	cml3xm2xd0004p284yvvs1sh8	cmkmikryv0002p20wmdaa77vd	вввввввввввв	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmlcagymn000sp2b81gdleeac	2026-02-07 12:27:00.816	2026-02-07 12:28:46.936	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 13:00:00	\N	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	фффффффф	CLIENT_CANCELED	\N	\N
cmkwtqopn000bp2wosrdexai7	2026-01-27 16:42:08.412	2026-02-07 13:46:39.057	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-01-27 18:00:00	1	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	CLIENT_CANCELED	\N	\N
cmkwtqm8v0009p2woo6jj12xs	2026-01-27 16:42:05.215	2026-02-07 13:46:41.139	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-01-27 17:30:00	1	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	CLIENT_CANCELED	\N	\N
cmkwtqh1n0007p2wo283lv20y	2026-01-27 16:41:58.475	2026-02-07 13:46:43.363	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-01-27 17:00:00	2	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	CLIENT_CANCELED	\N	\N
cmlcagkq6000qp2b8x4vhs2oj	2026-02-07 12:26:42.798	2026-02-07 13:46:50.694	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 13:00:00	\N	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	фффффффф	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmlcaolkt000vp2b8m3faod2v	2026-02-07 12:32:57.15	2026-02-07 13:46:54.453	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 13:00:00	\N	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikrz10004p20wyvrm0oz1	\N	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmlcagfvn000op2b8nvyskmfn	2026-02-07 12:26:36.516	2026-02-07 13:46:58.274	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 13:00:00	\N	cmkmundtt0001p2lk2zc5xaxe	cmkz9385i0001p2x0uetvdk1h	cmkmikryv0002p20wmdaa77vd	фффффффф	ADMIN_DELETED: Клиент не отвечает	\N	\N
cmlcddmiq000bp2qcp77zx19l	2026-02-07 13:48:24.002	2026-02-07 13:49:12.55	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 14:00:00	1	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryz0003p20wh6f36n97	стекла внутри не мыть	CLIENT_CANCELED	\N	\N
cmlcdf5a1000ep2qcxditdem9	2026-02-07 13:49:34.969	2026-02-07 13:51:15.204	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 14:00:00	1	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	ADMIN_DELETED: Клиент отменил	\N	\N
cmlcdi5u4000mp2qcxxqbuhwd	2026-02-07 13:51:55.661	2026-02-07 13:53:36.383	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-07 14:30:00	\N	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	ALL_BAYS_CLOSED	2026-02-07 13:53:36.382	cmlcdkbjq000sp2qc5nyixdhd
cmlce6wqq0005p2xsqsk8ej3t	2026-02-07 14:11:10.274	2026-02-07 14:11:23.467	CANCELED	cmkmikryn0000p20w74dgo9rk	2026-02-07 14:30:00	\N	cmkwnl6pz0012p2cg9njh1qrl	cmkwnlhiu0014p2cg1rp6pmkm	cmkmikryv0002p20wmdaa77vd	\N	CLIENT_CANCELED	\N	\N
cmlgn2eqe0004p25wbr7x71se	2026-02-10 13:30:41.559	2026-02-10 17:31:45.228	CONVERTED	cmkmikryn0000p20w74dgo9rk	2026-02-10 14:00:00	1	cmlgn2eq40000p25wjgtzz6ep	cmlgn2eqb0002p25wnv2hsxho	cmkmikryv0002p20wmdaa77vd	\N	ALL_BAYS_CLOSED_ADMIN	2026-02-10 17:31:45.227	cmlgvoeyp000ep25wa5ou5b64
\.


--
-- Data for Name: WasherClockEvent; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."WasherClockEvent" (id, "createdAt", "shiftWasherId", type, at) FROM stdin;
cmlphudfx0003p2o8pb7ssr1b	2026-02-16 18:14:24.142	cmlphg94u0001p2o8p04s1y01	CLOCK_IN	2026-02-16 18:14:24.132
cmlphuho20005p2o85xfn9qhw	2026-02-16 18:14:29.618	cmlphg94u0001p2o8p04s1y01	CLOCK_OUT	2026-02-16 18:14:29.613
\.


--
-- Data for Name: WasherPayRule; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public."WasherPayRule" (id, "createdAt", "updatedAt", "locationId", category, percent, "isActive") FROM stdin;
cmlpcok6y0017p24465c6o3sc	2026-02-16 15:49:54.874	2026-02-16 15:49:54.874	cmkmikryn0000p20w74dgo9rk	WASH	30	t
cmlpcok710019p244pxcay6s7	2026-02-16 15:49:54.877	2026-02-16 15:49:54.877	cmkmikryn0000p20w74dgo9rk	CHEM	40	t
cmlpcok72001bp2447fln2htc	2026-02-16 15:49:54.879	2026-02-16 15:49:54.879	cmkmikrys0001p20whl02brir	WASH	30	t
cmlpcok73001dp244n3h5k5uj	2026-02-16 15:49:54.88	2026-02-16 15:49:54.88	cmkmikrys0001p20whl02brir	CHEM	40	t
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: carwash
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
cc1d543a-ffca-4e4e-ad4a-e152aaf56677	5e7fb787a589a9d9a5b437620e8f455bb107e8b15a217a13efa61a482130af25	2026-01-29 11:57:57.579737+00	20260129115757_addons_photos_waitlist_convert	\N	\N	2026-01-29 11:57:57.547646+00	1
e3271933-d7c4-4da1-af88-76c293cf52d2	c4c60116f3ae38ba7dd59f31c5210cb1a490da3a1ffc1aae2efebeed4563c6fa	2026-01-20 11:31:38.880136+00	20251230085109_init	\N	\N	2026-01-20 11:31:38.857696+00	1
2c929a94-5c31-438a-a44b-865c9e190c49	374a7efae40774eff53885b45ef50d9241688b6659f3092c99dc0e7ae25f61a3	2026-01-20 11:31:39.035353+00	20260116152639_booking_slot_unique	\N	\N	2026-01-20 11:31:39.01672+00	1
443c08e4-0999-467e-aa68-55812a6e7b5b	143835472d55f6c1efcc79893bed5d4e4a7f71f5dc7d640b22ac6e9d9546a910	2026-01-20 11:31:38.887603+00	20251231130015_booking_status	\N	\N	2026-01-20 11:31:38.881539+00	1
76c49732-921e-48c1-b0ec-86e4c140684f	c957f119c09aeddc64f9f80359716aafbeac1e0d41eb1c80fab2def0e752e928	2026-01-20 11:31:38.892114+00	20251231132141_booking_canceled_at	\N	\N	2026-01-20 11:31:38.888599+00	1
643536f8-716c-4ac4-b36b-146dffaea06a	94e15cf2f9a0b4c9107526db02a156c5029cc02e04f13ab8c7201aa96e0e1f7d	2026-01-22 12:28:31.471635+00	20260122122256_tenant_feature_flags	\N	\N	2026-01-22 12:28:31.44799+00	1
93df50cb-ed88-40b9-8d7f-cf9d031841c2	f117a48f84335bcd96df9df734feec8095b7f0f107da1f6ead6a1a357161fa8b	2026-01-20 11:31:38.896551+00	20260104120124_add_completed_status	\N	\N	2026-01-20 11:31:38.893121+00	1
6d43e5f6-b639-4bdf-a26d-66c32e902665	1d7f0616c86c6a6f098d71d53c24e14010899d4ad68a439df2a17de8b10fb84f	2026-01-20 11:31:39.0549+00	20260120103933_add_locations	\N	\N	2026-01-20 11:31:39.037308+00	1
f565a553-f004-4bbd-b018-d01c73637e88	b977cfd1e12aec1e551af87d3fed6eb9a7dcaee9466d25707845cb65f3f93c94	2026-01-20 11:31:38.900769+00	20260105123448_add_service_duration	\N	\N	2026-01-20 11:31:38.897665+00	1
36b5eea7-bbe3-4a6a-b97d-33266925aa52	b389192e97e982bc37d7d21b5635ce776b26aa196b983e8e7949be70ee95d1c0	2026-01-20 11:31:38.905244+00	20260105130758_add_service_duration	\N	\N	2026-01-20 11:31:38.901898+00	1
975661db-34e8-4422-9970-ce9568589b08	9657c43cbce9d5dc3fd89163de1e66cada891af896cf5faeac910458497fe8d7	2026-01-20 11:31:38.909616+00	20260105144507_service_duration_default	\N	\N	2026-01-20 11:31:38.906277+00	1
30b7642c-1976-4ce3-942d-6fe0cfa48b1e	ae4065e43ea6b8032925a6b69565857cb544cb29c5fdfe9a3f244ecd5296e3c8	2026-01-20 11:31:39.075416+00	20260120111115_booking_slot_unique_active_pending_location	\N	\N	2026-01-20 11:31:39.056053+00	1
f9856586-4859-416d-ae4b-edd56a7fbf00	84b746e6448973cbc38f601de6fa077669f03521feda36c36fc193ccac253f8a	2026-01-20 11:31:38.93842+00	20260106173246_add_pending_payment_enum	\N	\N	2026-01-20 11:31:38.910769+00	1
9363efa1-162b-419e-8bf8-af953e7cd8fb	0f58ac0fa0cfab47e411f384655a2413c454128aa3810bd0d2d5648bae5d4140	2026-01-20 11:31:38.945302+00	20260106173315_booking_default_pending_payment	\N	\N	2026-01-20 11:31:38.940612+00	1
dc860f44-1b4a-474e-a952-17184b76c924	303622131be8c0a5a95654a6284c7d815911d800af9375c5d2b9620e429e9abd	2026-01-20 11:31:38.953057+00	20260114184951_booking_deposit_buffer_comment	\N	\N	2026-01-20 11:31:38.94648+00	1
43ddb374-6f71-4757-b1c8-7184b4b7772b	fce0be0f5bfff9f78eead36fc6c26de6adc6753f4d4b3c5aeca89df386c275b1	2026-01-21 08:03:15.433981+00	20260121080315_admin_foundation	\N	\N	2026-01-21 08:03:15.359781+00	1
d477276c-9f8e-41db-8657-4ddcc0f58ea5	9ec75df59e728cf6c83d47c011952ebdd54bcf13cf767a1477a694442cc262a9	2026-01-20 11:31:38.968241+00	20260114201150_add_payments	\N	\N	2026-01-20 11:31:38.954191+00	1
ad1373fd-123d-485e-9b95-86717852da42	2716fdfe0686d8ec73d3af62754326c5ae9fc7be438eeac918278926d4586e4c	2026-01-20 11:31:38.998746+00	20260115105927_add_payment_table	\N	\N	2026-01-20 11:31:38.969445+00	1
2d0a3100-5e73-4b68-9cbf-61fd2ad87a22	3cdfad43315ef36061ea765d557359f8d94e34b66798eb0f367c44acf1ce388a	2026-01-22 12:28:31.790924+00	20260122122831_tenant_feature_flags	\N	\N	2026-01-22 12:28:31.782191+00	1
dbdffac3-36a0-46c4-b0cf-a9ffda76f01f	063e533e3dc7f94596bdec6e4a9a26a8f2838ef1388882c8769f2586f2b2c48e	2026-01-20 11:31:39.015273+00	20260115125620_add_client	\N	\N	2026-01-20 11:31:39.000079+00	1
4cc35a35-1f7c-4026-bfec-3447ff1b4ca7	6b6ed623d5727edb27e636d009afea0db9b0530a69f7c4254ff5289ee98bf5c3	2026-01-21 08:43:03.35189+00	20260121084303_client_location_membership	\N	\N	2026-01-21 08:43:03.322064+00	1
c2243753-2ca5-4f06-a7a0-d37a01174b73	b76b6212b046b4cca8ad7563ec96e6f70d5f2e35e98ff61481d8da8fcdc07119	2026-01-21 11:09:40.379216+00	20260121110940_audit_booking_start_finish	\N	\N	2026-01-21 11:09:40.374172+00	1
979391b9-fa1d-45ca-a72b-976e7b111738	eef742d33ae8789ce9674869bde8b405a84eff7d774351cc6a248f394d40f9d2	2026-02-16 15:46:00.088775+00	20260216154600_washer_shifts_and_payout_rules	\N	\N	2026-02-16 15:46:00.048952+00	1
2e6aa190-79e0-403a-aa1b-3d2be793f545	b9f5e8cf4ff15fe43dc7d3c4a09e89dabe8021ddb6f0bafca5334480d81473db	2026-01-22 08:55:19.065211+00	20260122085519_shift_cash_events	\N	\N	2026-01-22 08:55:19.050382+00	1
ea7f9541-1a49-43d6-9b01-ed29755b123f	ff3bac084a71dcbea07e23059f88356764b34d9846cc18f2370053c840e258df	2026-01-22 16:36:37.435193+00	20260122163637_admin_payment_marked	\N	\N	2026-01-22 16:36:37.423289+00	1
17846907-779e-4d34-9a1a-abea64987a81	30194fb6d94d89970701a056cfb47108344c9ea96fb725c59d90bf75267c98ef	2026-01-22 09:14:05.769826+00	20260122091405_payments_method_type_and_cash_expected	\N	\N	2026-01-22 09:14:05.761971+00	1
5d9aa4b6-f75d-4a7c-8f1d-d9264da7a5e6	810bba364696f1e54255cfe160d5b654fab87b3429c8e42cac66b6ba81f235af	2026-01-29 12:12:07.019629+00	20260129121206_addons_photos_waitlist	\N	\N	2026-01-29 12:12:07.01098+00	1
6f79de73-6ca8-4f08-ab0f-784ac29fcfd8	344445d77a8ee15f17001334fd60937c68ad0c22cb3670c90fd9d3b2aa702d1f	2026-01-25 11:01:53.274655+00	20260125110153_booking_discount	\N	\N	2026-01-25 11:01:53.267443+00	1
e692a435-edb2-4e85-9d28-0a77314cf93d	b4500d012e4c11a8cf2f447c691c5ec2a5afbe16120ccff30e980be677674c04	2026-01-27 09:08:25.950137+00	20260127090825_waitlist	\N	\N	2026-01-27 09:08:25.921927+00	1
0722e229-c9c7-4979-8679-9bb334242f99	ac32e4b860d36daa79e5fa8b7ad2bbe060de5c795d168e697eb55b5c1ae80f82	2026-02-10 09:31:44.614001+00	20260210093144_services_step1_nullable	\N	\N	2026-02-10 09:31:44.598264+00	1
35a533d4-e7e4-42c7-93cd-f641897d9e89	352234cac50324a1a9efa43dd5831cfb137b6c3ed3d26184f3bdda7ea919942a	2026-02-05 07:46:47.521732+00	20260205074647_add_requested_bay	\N	\N	2026-02-05 07:46:47.511955+00	1
1bdc4a51-a4fe-4f6d-a90e-1759ea033fc0	59a143e45a5cf452bf1e058e920d1e4656a49a8700857d2d35aa61eea27e7ee9	2026-02-07 09:50:00.050974+00	20260207095000_waitlist_delete_audit	\N	\N	2026-02-07 09:50:00.045605+00	1
87712131-e1db-4dae-b8ff-c24403430a3b	bfcfea3bd5ed169382d67374f862174914da8f5a1b4500ad9d350ad89f19a280	2026-02-10 09:49:22.829776+00	20260210094922_services_step2_required	\N	\N	2026-02-10 09:49:22.819584+00	1
58d22a65-b2ec-4c90-aef7-7cb1447539b3	11c4e874742ba52209f64115288ab77573adf789dd21f7575f015675b54e9804	2026-02-17 13:06:43.796959+00	20260217130643_planned_shifts	\N	\N	2026-02-17 13:06:43.769795+00	1
\.


--
-- Name: AuditEvent AuditEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."AuditEvent"
    ADD CONSTRAINT "AuditEvent_pkey" PRIMARY KEY (id);


--
-- Name: Bay Bay_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Bay"
    ADD CONSTRAINT "Bay_pkey" PRIMARY KEY (id);


--
-- Name: BookingAddon BookingAddon_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingAddon"
    ADD CONSTRAINT "BookingAddon_pkey" PRIMARY KEY (id);


--
-- Name: BookingPhoto BookingPhoto_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingPhoto"
    ADD CONSTRAINT "BookingPhoto_pkey" PRIMARY KEY (id);


--
-- Name: Booking Booking_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_pkey" PRIMARY KEY (id);


--
-- Name: Car Car_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Car"
    ADD CONSTRAINT "Car_pkey" PRIMARY KEY (id);


--
-- Name: ClientLocation ClientLocation_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ClientLocation"
    ADD CONSTRAINT "ClientLocation_pkey" PRIMARY KEY (id);


--
-- Name: Client Client_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Client"
    ADD CONSTRAINT "Client_pkey" PRIMARY KEY (id);


--
-- Name: Location Location_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Location"
    ADD CONSTRAINT "Location_pkey" PRIMARY KEY (id);


--
-- Name: Payment Payment_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Payment"
    ADD CONSTRAINT "Payment_pkey" PRIMARY KEY (id);


--
-- Name: PlannedShiftWasher PlannedShiftWasher_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShiftWasher"
    ADD CONSTRAINT "PlannedShiftWasher_pkey" PRIMARY KEY (id);


--
-- Name: PlannedShift PlannedShift_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShift"
    ADD CONSTRAINT "PlannedShift_pkey" PRIMARY KEY (id);


--
-- Name: Service Service_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_pkey" PRIMARY KEY (id);


--
-- Name: ShiftCashEvent ShiftCashEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftCashEvent"
    ADD CONSTRAINT "ShiftCashEvent_pkey" PRIMARY KEY (id);


--
-- Name: ShiftWasher ShiftWasher_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftWasher"
    ADD CONSTRAINT "ShiftWasher_pkey" PRIMARY KEY (id);


--
-- Name: Shift Shift_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Shift"
    ADD CONSTRAINT "Shift_pkey" PRIMARY KEY (id);


--
-- Name: TenantFeature TenantFeature_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."TenantFeature"
    ADD CONSTRAINT "TenantFeature_pkey" PRIMARY KEY (id);


--
-- Name: Tenant Tenant_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Tenant"
    ADD CONSTRAINT "Tenant_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: WaitlistRequest WaitlistRequest_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_pkey" PRIMARY KEY (id);


--
-- Name: WasherClockEvent WasherClockEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WasherClockEvent"
    ADD CONSTRAINT "WasherClockEvent_pkey" PRIMARY KEY (id);


--
-- Name: WasherPayRule WasherPayRule_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WasherPayRule"
    ADD CONSTRAINT "WasherPayRule_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: AuditEvent_bookingId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_bookingId_idx" ON public."AuditEvent" USING btree ("bookingId");


--
-- Name: AuditEvent_clientId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_clientId_idx" ON public."AuditEvent" USING btree ("clientId");


--
-- Name: AuditEvent_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_createdAt_idx" ON public."AuditEvent" USING btree ("createdAt");


--
-- Name: AuditEvent_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_locationId_idx" ON public."AuditEvent" USING btree ("locationId");


--
-- Name: AuditEvent_shiftId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_shiftId_idx" ON public."AuditEvent" USING btree ("shiftId");


--
-- Name: AuditEvent_type_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_type_idx" ON public."AuditEvent" USING btree (type);


--
-- Name: AuditEvent_userId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "AuditEvent_userId_idx" ON public."AuditEvent" USING btree ("userId");


--
-- Name: Bay_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Bay_locationId_idx" ON public."Bay" USING btree ("locationId");


--
-- Name: Bay_locationId_isActive_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Bay_locationId_isActive_idx" ON public."Bay" USING btree ("locationId", "isActive");


--
-- Name: Bay_locationId_number_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Bay_locationId_number_key" ON public."Bay" USING btree ("locationId", number);


--
-- Name: BookingAddon_bookingId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "BookingAddon_bookingId_createdAt_idx" ON public."BookingAddon" USING btree ("bookingId", "createdAt");


--
-- Name: BookingAddon_bookingId_serviceId_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "BookingAddon_bookingId_serviceId_key" ON public."BookingAddon" USING btree ("bookingId", "serviceId");


--
-- Name: BookingAddon_serviceId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "BookingAddon_serviceId_idx" ON public."BookingAddon" USING btree ("serviceId");


--
-- Name: BookingPhoto_bookingId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "BookingPhoto_bookingId_createdAt_idx" ON public."BookingPhoto" USING btree ("bookingId", "createdAt");


--
-- Name: BookingPhoto_kind_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "BookingPhoto_kind_idx" ON public."BookingPhoto" USING btree (kind);


--
-- Name: BookingPhoto_uploadedByUserId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "BookingPhoto_uploadedByUserId_idx" ON public."BookingPhoto" USING btree ("uploadedByUserId");


--
-- Name: Booking_bayId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_bayId_idx" ON public."Booking" USING btree ("bayId");


--
-- Name: Booking_carId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_carId_idx" ON public."Booking" USING btree ("carId");


--
-- Name: Booking_clientId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_clientId_idx" ON public."Booking" USING btree ("clientId");


--
-- Name: Booking_dateTime_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_dateTime_idx" ON public."Booking" USING btree ("dateTime");


--
-- Name: Booking_locationId_bayId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_locationId_bayId_idx" ON public."Booking" USING btree ("locationId", "bayId");


--
-- Name: Booking_locationId_dateTime_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_locationId_dateTime_idx" ON public."Booking" USING btree ("locationId", "dateTime");


--
-- Name: Booking_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_locationId_idx" ON public."Booking" USING btree ("locationId");


--
-- Name: Booking_paymentDueAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_paymentDueAt_idx" ON public."Booking" USING btree ("paymentDueAt");


--
-- Name: Booking_requestedBayId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_requestedBayId_idx" ON public."Booking" USING btree ("requestedBayId");


--
-- Name: Booking_serviceId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_serviceId_idx" ON public."Booking" USING btree ("serviceId");


--
-- Name: Booking_shiftId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_shiftId_idx" ON public."Booking" USING btree ("shiftId");


--
-- Name: Booking_status_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Booking_status_idx" ON public."Booking" USING btree (status);


--
-- Name: Car_clientId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Car_clientId_idx" ON public."Car" USING btree ("clientId");


--
-- Name: Car_plateNormalized_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Car_plateNormalized_key" ON public."Car" USING btree ("plateNormalized");


--
-- Name: ClientLocation_clientId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ClientLocation_clientId_idx" ON public."ClientLocation" USING btree ("clientId");


--
-- Name: ClientLocation_clientId_locationId_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "ClientLocation_clientId_locationId_key" ON public."ClientLocation" USING btree ("clientId", "locationId");


--
-- Name: ClientLocation_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ClientLocation_locationId_idx" ON public."ClientLocation" USING btree ("locationId");


--
-- Name: ClientLocation_locationId_isBlocked_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ClientLocation_locationId_isBlocked_idx" ON public."ClientLocation" USING btree ("locationId", "isBlocked");


--
-- Name: Client_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Client_createdAt_idx" ON public."Client" USING btree ("createdAt");


--
-- Name: Client_isBlocked_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Client_isBlocked_idx" ON public."Client" USING btree ("isBlocked");


--
-- Name: Client_phone_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Client_phone_idx" ON public."Client" USING btree (phone);


--
-- Name: Client_phone_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Client_phone_key" ON public."Client" USING btree (phone);


--
-- Name: Location_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Location_createdAt_idx" ON public."Location" USING btree ("createdAt");


--
-- Name: Location_name_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Location_name_key" ON public."Location" USING btree (name);


--
-- Name: Location_tenantId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Location_tenantId_idx" ON public."Location" USING btree ("tenantId");


--
-- Name: Payment_bookingId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Payment_bookingId_idx" ON public."Payment" USING btree ("bookingId");


--
-- Name: Payment_bookingId_kind_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Payment_bookingId_kind_key" ON public."Payment" USING btree ("bookingId", kind);


--
-- Name: Payment_kind_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Payment_kind_idx" ON public."Payment" USING btree (kind);


--
-- Name: Payment_methodType_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Payment_methodType_idx" ON public."Payment" USING btree ("methodType");


--
-- Name: Payment_paidAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Payment_paidAt_idx" ON public."Payment" USING btree ("paidAt");


--
-- Name: PlannedShiftWasher_plannedShiftId_plannedBayId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "PlannedShiftWasher_plannedShiftId_plannedBayId_idx" ON public."PlannedShiftWasher" USING btree ("plannedShiftId", "plannedBayId");


--
-- Name: PlannedShiftWasher_plannedShiftId_washerId_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "PlannedShiftWasher_plannedShiftId_washerId_key" ON public."PlannedShiftWasher" USING btree ("plannedShiftId", "washerId");


--
-- Name: PlannedShiftWasher_washerId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "PlannedShiftWasher_washerId_createdAt_idx" ON public."PlannedShiftWasher" USING btree ("washerId", "createdAt");


--
-- Name: PlannedShift_createdByUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "PlannedShift_createdByUserId_createdAt_idx" ON public."PlannedShift" USING btree ("createdByUserId", "createdAt");


--
-- Name: PlannedShift_locationId_startAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "PlannedShift_locationId_startAt_idx" ON public."PlannedShift" USING btree ("locationId", "startAt");


--
-- Name: PlannedShift_status_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "PlannedShift_status_idx" ON public."PlannedShift" USING btree (status);


--
-- Name: Service_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_createdAt_idx" ON public."Service" USING btree ("createdAt");


--
-- Name: Service_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_locationId_idx" ON public."Service" USING btree ("locationId");


--
-- Name: Service_locationId_isActive_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_locationId_isActive_idx" ON public."Service" USING btree ("locationId", "isActive");


--
-- Name: Service_locationId_kind_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_locationId_kind_idx" ON public."Service" USING btree ("locationId", kind);


--
-- Name: Service_locationId_laborCategory_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_locationId_laborCategory_idx" ON public."Service" USING btree ("locationId", "laborCategory");


--
-- Name: Service_locationId_name_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "Service_locationId_name_key" ON public."Service" USING btree ("locationId", name);


--
-- Name: Service_locationId_sortOrder_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Service_locationId_sortOrder_idx" ON public."Service" USING btree ("locationId", "sortOrder");


--
-- Name: ShiftCashEvent_adminId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftCashEvent_adminId_createdAt_idx" ON public."ShiftCashEvent" USING btree ("adminId", "createdAt");


--
-- Name: ShiftCashEvent_locationId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftCashEvent_locationId_createdAt_idx" ON public."ShiftCashEvent" USING btree ("locationId", "createdAt");


--
-- Name: ShiftCashEvent_shiftId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftCashEvent_shiftId_createdAt_idx" ON public."ShiftCashEvent" USING btree ("shiftId", "createdAt");


--
-- Name: ShiftCashEvent_type_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftCashEvent_type_idx" ON public."ShiftCashEvent" USING btree (type);


--
-- Name: ShiftWasher_clockInAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftWasher_clockInAt_idx" ON public."ShiftWasher" USING btree ("clockInAt");


--
-- Name: ShiftWasher_clockOutAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftWasher_clockOutAt_idx" ON public."ShiftWasher" USING btree ("clockOutAt");


--
-- Name: ShiftWasher_shiftId_bayId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftWasher_shiftId_bayId_idx" ON public."ShiftWasher" USING btree ("shiftId", "bayId");


--
-- Name: ShiftWasher_shiftId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftWasher_shiftId_idx" ON public."ShiftWasher" USING btree ("shiftId");


--
-- Name: ShiftWasher_shiftId_washerId_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "ShiftWasher_shiftId_washerId_key" ON public."ShiftWasher" USING btree ("shiftId", "washerId");


--
-- Name: ShiftWasher_washerId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "ShiftWasher_washerId_idx" ON public."ShiftWasher" USING btree ("washerId");


--
-- Name: Shift_adminId_openedAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Shift_adminId_openedAt_idx" ON public."Shift" USING btree ("adminId", "openedAt");


--
-- Name: Shift_locationId_openedAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Shift_locationId_openedAt_idx" ON public."Shift" USING btree ("locationId", "openedAt");


--
-- Name: Shift_plannedShiftId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Shift_plannedShiftId_idx" ON public."Shift" USING btree ("plannedShiftId");


--
-- Name: Shift_status_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Shift_status_idx" ON public."Shift" USING btree (status);


--
-- Name: TenantFeature_enabled_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "TenantFeature_enabled_idx" ON public."TenantFeature" USING btree (enabled);


--
-- Name: TenantFeature_key_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "TenantFeature_key_idx" ON public."TenantFeature" USING btree (key);


--
-- Name: TenantFeature_tenantId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "TenantFeature_tenantId_idx" ON public."TenantFeature" USING btree ("tenantId");


--
-- Name: TenantFeature_tenantId_key_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "TenantFeature_tenantId_key_key" ON public."TenantFeature" USING btree ("tenantId", key);


--
-- Name: Tenant_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Tenant_createdAt_idx" ON public."Tenant" USING btree ("createdAt");


--
-- Name: Tenant_isActive_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "Tenant_isActive_idx" ON public."Tenant" USING btree ("isActive");


--
-- Name: User_isActive_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "User_isActive_idx" ON public."User" USING btree ("isActive");


--
-- Name: User_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "User_locationId_idx" ON public."User" USING btree ("locationId");


--
-- Name: User_phone_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "User_phone_key" ON public."User" USING btree (phone);


--
-- Name: User_role_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "User_role_idx" ON public."User" USING btree (role);


--
-- Name: WaitlistRequest_clientId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WaitlistRequest_clientId_createdAt_idx" ON public."WaitlistRequest" USING btree ("clientId", "createdAt");


--
-- Name: WaitlistRequest_convertedBookingId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WaitlistRequest_convertedBookingId_idx" ON public."WaitlistRequest" USING btree ("convertedBookingId");


--
-- Name: WaitlistRequest_desiredDateTime_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WaitlistRequest_desiredDateTime_idx" ON public."WaitlistRequest" USING btree ("desiredDateTime");


--
-- Name: WaitlistRequest_locationId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WaitlistRequest_locationId_createdAt_idx" ON public."WaitlistRequest" USING btree ("locationId", "createdAt");


--
-- Name: WaitlistRequest_locationId_status_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WaitlistRequest_locationId_status_idx" ON public."WaitlistRequest" USING btree ("locationId", status);


--
-- Name: WasherClockEvent_shiftWasherId_createdAt_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WasherClockEvent_shiftWasherId_createdAt_idx" ON public."WasherClockEvent" USING btree ("shiftWasherId", "createdAt");


--
-- Name: WasherClockEvent_type_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WasherClockEvent_type_idx" ON public."WasherClockEvent" USING btree (type);


--
-- Name: WasherPayRule_category_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WasherPayRule_category_idx" ON public."WasherPayRule" USING btree (category);


--
-- Name: WasherPayRule_isActive_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WasherPayRule_isActive_idx" ON public."WasherPayRule" USING btree ("isActive");


--
-- Name: WasherPayRule_locationId_category_key; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX "WasherPayRule_locationId_category_key" ON public."WasherPayRule" USING btree ("locationId", category);


--
-- Name: WasherPayRule_locationId_idx; Type: INDEX; Schema: public; Owner: carwash
--

CREATE INDEX "WasherPayRule_locationId_idx" ON public."WasherPayRule" USING btree ("locationId");


--
-- Name: booking_slot_unique_active_pending; Type: INDEX; Schema: public; Owner: carwash
--

CREATE UNIQUE INDEX booking_slot_unique_active_pending ON public."Booking" USING btree ("bayId", "dateTime") WHERE (status = ANY (ARRAY['ACTIVE'::public."BookingStatus", 'PENDING_PAYMENT'::public."BookingStatus"]));


--
-- Name: AuditEvent AuditEvent_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."AuditEvent"
    ADD CONSTRAINT "AuditEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Bay Bay_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Bay"
    ADD CONSTRAINT "Bay_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: BookingAddon BookingAddon_bookingId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingAddon"
    ADD CONSTRAINT "BookingAddon_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES public."Booking"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: BookingAddon BookingAddon_serviceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingAddon"
    ADD CONSTRAINT "BookingAddon_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES public."Service"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: BookingPhoto BookingPhoto_bookingId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingPhoto"
    ADD CONSTRAINT "BookingPhoto_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES public."Booking"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: BookingPhoto BookingPhoto_uploadedByUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."BookingPhoto"
    ADD CONSTRAINT "BookingPhoto_uploadedByUserId_fkey" FOREIGN KEY ("uploadedByUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Booking Booking_carId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_carId_fkey" FOREIGN KEY ("carId") REFERENCES public."Car"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Booking Booking_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."Client"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Booking Booking_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Booking Booking_serviceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES public."Service"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Booking Booking_shiftId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Booking"
    ADD CONSTRAINT "Booking_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES public."Shift"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Car Car_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Car"
    ADD CONSTRAINT "Car_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."Client"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: ClientLocation ClientLocation_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ClientLocation"
    ADD CONSTRAINT "ClientLocation_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."Client"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ClientLocation ClientLocation_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ClientLocation"
    ADD CONSTRAINT "ClientLocation_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Location Location_tenantId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Location"
    ADD CONSTRAINT "Location_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES public."Tenant"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Payment Payment_bookingId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Payment"
    ADD CONSTRAINT "Payment_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES public."Booking"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: PlannedShiftWasher PlannedShiftWasher_plannedShiftId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShiftWasher"
    ADD CONSTRAINT "PlannedShiftWasher_plannedShiftId_fkey" FOREIGN KEY ("plannedShiftId") REFERENCES public."PlannedShift"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: PlannedShiftWasher PlannedShiftWasher_washerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShiftWasher"
    ADD CONSTRAINT "PlannedShiftWasher_washerId_fkey" FOREIGN KEY ("washerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: PlannedShift PlannedShift_createdByUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShift"
    ADD CONSTRAINT "PlannedShift_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: PlannedShift PlannedShift_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."PlannedShift"
    ADD CONSTRAINT "PlannedShift_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Service Service_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ShiftCashEvent ShiftCashEvent_adminId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftCashEvent"
    ADD CONSTRAINT "ShiftCashEvent_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ShiftCashEvent ShiftCashEvent_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftCashEvent"
    ADD CONSTRAINT "ShiftCashEvent_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ShiftCashEvent ShiftCashEvent_shiftId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftCashEvent"
    ADD CONSTRAINT "ShiftCashEvent_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES public."Shift"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ShiftWasher ShiftWasher_shiftId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftWasher"
    ADD CONSTRAINT "ShiftWasher_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES public."Shift"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ShiftWasher ShiftWasher_washerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."ShiftWasher"
    ADD CONSTRAINT "ShiftWasher_washerId_fkey" FOREIGN KEY ("washerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Shift Shift_adminId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Shift"
    ADD CONSTRAINT "Shift_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Shift Shift_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Shift"
    ADD CONSTRAINT "Shift_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Shift Shift_plannedShiftId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."Shift"
    ADD CONSTRAINT "Shift_plannedShiftId_fkey" FOREIGN KEY ("plannedShiftId") REFERENCES public."PlannedShift"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: TenantFeature TenantFeature_tenantId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."TenantFeature"
    ADD CONSTRAINT "TenantFeature_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES public."Tenant"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: User User_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WaitlistRequest WaitlistRequest_carId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_carId_fkey" FOREIGN KEY ("carId") REFERENCES public."Car"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WaitlistRequest WaitlistRequest_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."Client"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WaitlistRequest WaitlistRequest_convertedBookingId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_convertedBookingId_fkey" FOREIGN KEY ("convertedBookingId") REFERENCES public."Booking"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: WaitlistRequest WaitlistRequest_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WaitlistRequest WaitlistRequest_serviceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WaitlistRequest"
    ADD CONSTRAINT "WaitlistRequest_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES public."Service"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WasherClockEvent WasherClockEvent_shiftWasherId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WasherClockEvent"
    ADD CONSTRAINT "WasherClockEvent_shiftWasherId_fkey" FOREIGN KEY ("shiftWasherId") REFERENCES public."ShiftWasher"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: WasherPayRule WasherPayRule_locationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: carwash
--

ALTER TABLE ONLY public."WasherPayRule"
    ADD CONSTRAINT "WasherPayRule_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES public."Location"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: carwash
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict EsY5pYIvw1m8SMpJo1kiugZFEQTEBS0DgdULY0gzK0S2JjDxzMuoybTAObFD0gE

