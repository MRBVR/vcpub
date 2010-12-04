
(*
	----------------------------------------------
	  unaClasses.pas
	----------------------------------------------
	  Copyright (c) 2001-2010 Lake of Soft
		     All rights reserved

	  http://lakeofsoft.com/
	----------------------------------------------

	  created by:
		Lake, 25 Aug 2001

	  modified by:
		Lake, Aug-Dec 2001
		Lake, Jan-Dec 2002
		Lake, Jan-Dec 2003
		Lake, Jan-Dec 2004
		Lake, Jan-Dec 2005
		Lake, Jan-Dec 2006
		Lake, Jan-Dec 2007
		Lake, Jan-Oct 2008
		Lake, Jan-Dec 2009
		Lake, Jan-Nov 2010

	----------------------------------------------
*)

{$I unaDef.inc }

{$IFDEF DEBUG }
  //
  {$DEFINE LOG_UNACLASSES_INFOS }	// log informational messages
  {$DEFINE LOG_UNACLASSES_ERRORS }	// log critical error messages
  //
  {xx $DEFINE UNA_GATE_DEBUG }
  {xx $DEFINE UNA_GATE_DEBUG_TIMEOUT }
{$ENDIF DEBUG }

{*
  Contains base classes, such as lists, threads and events,
  which are often used by other classes and components.

  @Author Lake
  @Version 2.5.2008.03
  @Version 2.5.2009.12 	  - removed old critical section/asm stuff from gates' implementation
  @Version 2.5.2010.01    - compatiblity with D4/D5 restored; some cleanup
  @Version 2.5.2010.01.26 - unaIniFile now supports unicode values
}

unit
  unaClasses;

interface

uses
  Windows,
  unaTypes, unaUtils
{$IFDEF UNA_PROFILE }
  , unaProfile
{$ENDIF UNA_PROFILE }
{$IFDEF __SYSUTILS_H_ }
  , SysUtils
{$ENDIF __SYSUTILS_H_ }
  ;

const
  //
  c_VC_reg_core_section_name 	= 'VC2.5';
  c_VC_reg_DSP_section_name 	= 'VC2.5 DSP';
  c_VC_reg_RTP_section_name	= 'VC2.5 RTP';


type
  //
  // -- basic class --
  //
  {*
	Base class for all objects defined in this unit.
  }
  unaObject = class
  private
  {$IFDEF LOG_UNACLASSES_INFOS }
    f_inheritedCreateWasCalled: bool;
  {$ENDIF LOG_UNACLASSES_INFOS }
    //
    f_acqObj: unaAcquireType;
    f_acqThreadID: DWORD;
    //
    function getThis(): unaObject;
    function getClassID(): string;
  protected
    f_destroyed: bool;
  public
    {*
	Creates an object.
    }
    constructor create();
    //
    {*
	Returns pointer to self (this instance of object). Useful is some cases where self will refer to method's owner object instead.
    }
    property _this: unaObject read getThis;
    {*
	Returns string description of this instance.
    }
    property _classID: string read getClassID;
    {*
	Makes sure "inherited" create() was called during object's creation.
    }
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    {*
	Exclusive acquire.
    }
    function acquire(timeout: int; fsn: bool = false): bool; overload;
    {
	Non-exclusive acquire. Always succeed. Do not forget to call release.
    }
    procedure acquire(); overload;
    {*
    }
    class function acquireStatic(timeout: int): bool; overload;
    {*
    }
    class procedure acquireStatic(); overload;
    {*
    }
    function release(): bool;
  end;

  //
  // -- unaEvent --
  //
  {*
    This is a wrapper class for Windows Events.
  }
  unaEvent = class(unaObject)
  private
    f_handle: tHandle;
    f_name: wString;
  public
    {*
      Constructs an event. Specify initialState and manualReset parameters.
      Refer to MSDN documentation for more details about Windows events.

      @param manualReset If manualReset is true you have to reset the event manually every time it was set to signaled state. By default this parameter is False, what means event will be reset automatically.
      @param initialState Specifies the initial state of event. Default value is False (non-signaled).
      @param name Specifies optional name of the event. You can use this name later to reopen the event.
    }
    constructor create(manualReset: bool = false; initialState: bool = false; const name: wString = '');
    {*
    	Destroys an event object by closing its handle.
    }
    destructor Destroy(); override;
    //
    {*
      	Sets the state of an event to signaled or non-signaled.
    }
    procedure setState(signaled: bool = true);
    {*
	Used to wait until the state of event will be set to signaled.
	This method blocks execution of the caller thread, so use it carefully when specifying INFINITE value for timeout.

	@param timeout Specifies the timeout in milliseconds.

	@return True if the event is now signaled or False if timeout was expired (event remains in non-signaled state).
    }
    function waitFor(timeout: unsigned = 1): bool;
    {*
      Windows handle of event.
    }
    property handle: tHandle read f_handle;
    {*
      Event's name (if specified).
    }
    property name: wString read f_name;
  end;


  //
  // -- unaAbstractGate --
  //
  {*
	Abstract class for all gates (critical sections) objects.
  }
  unaAbstractGate = class(unaObject)
  private
  {$IFDEF DEBUG }
    f_title: string;
    f_masterName: string;
  {$ENDIF DEBUG }
  {$IFDEF UNA_GATE_PROFILE }
    f_profileIndexEnter2: unsigned;
    f_profileIndexLeave2: unsigned;
  {$ENDIF UNA_GATE_PROFILE }
  protected
    f_isBusy: bool;
    //
    function gateEnter(timeout: unsigned = INFINITE{$IFDEF DEBUG}; const masterName: string = ''{$ENDIF}): bool; virtual;
    procedure gateLeave(); virtual;
  public
    constructor create({$IFDEF DEBUG }const title: string = ''{$ENDIF});
    {*
      Enters the gate. timeout parameter specifies the amount of time (in milliseconds) attempt to enter the gate should last.
      Returns false if gate cannot be entered and timeout was expired.
      Returns true if gate was entered successfully.
      Default timeout value is INFINITE. That means routine should wait forever, until gate will be freed.
      Use this default value carefully, as it could lead to deadlocks in your application.
    }
    function enter(timeout: unsigned = INFINITE{$IFDEF DEBUG }; const masterName: string = ''{$ENDIF DEBUG }): bool;
    {*
      Every successful enter() must be followed by leave().
      Do not call leave() unless enter() returns true.
    }
    procedure leave();
  {$IFDEF DEBUG }
    property masterName: string read f_masterName;
  {$ENDIF DEBUG }
    {*
      Indicates if gate is busy by one ore more threads.
      Do not use this property if you want to make sure gate is free. Use enter() instead.
      The only good use for this property is in some kind of visual indication to end-user whether the gate is free.
    }
    property isBusy: bool read f_isBusy;
  end;

  //
  // -- unaOutProcessGate --
  //
  {*
    This class is useful when you wish to ensure some block of code to be executed only by one thread at a time.
    Only one instance can enter the gate. You should use <STRONG>try</STRONG> <STRONG>finally</STRONG> block to ensure you always leave the gate.
  }
  unaOutProcessGate = class(unaAbstractGate)
  private
    f_inside: bool;
    f_masterThread: tHandle;
  {$IFDEF DEBUG }
    f_title: string;
  {$ENDIF DEBUG }
    f_event: unaEvent;
  protected
    function gateEnter(timeout: unsigned = INFINITE{$IFDEF DEBUG }; const masterName: string = ''{$ENDIF}): bool; override;
    procedure gateLeave(); override;
  public
    constructor create({$IFDEF DEBUG }const title: string = ''{$ENDIF});
    destructor Destroy(); override;
    //
    function checkDeadlock(timeout: unsigned = INFINITE; const name: string = ''): bool;
    //
  {$IFDEF DEBUG }
    property title: string read f_title;
  {$ENDIF DEBUG }
  end;


  //
  // -- unaInProcessGate --
  //
  {*
    Only one thead at a time can enter this gate. This thread can enter the gate as many times as required.
    Gate will be released when thread will leave it exactly same number of times as was entered.
  }
  unaInProcessGate = class(unaAbstractGate)
  private
    f_obj: unaAcquireType;
    f_threadID: DWORD;
    f_rlc: int;
  protected
    function gateEnter(timeout: unsigned = INFINITE{$IFDEF DEBUG }; const masterName: string = ''{$ENDIF}): bool; override;
    procedure gateLeave(); override;
  public
    {*
      Owning thread ID.
    }
    property owningThreadId: DWORD read f_threadID;
    {*
      Number of locks made by owning thread.
    }
    property recursionLockCount: int read f_rlc;
  end;


  // --  --
  unaListCopyOpEnum = (unaco_add, unaco_replaceExisting, unaco_insert, unaco_assign);

  //
  // -- unaList --
  //
  {*
    Fires when list item is needed to be released. NOTE: item[index] could be nil.
  }
  unaListOnItemReleaseEvent = procedure(index: int; var doFree: unsigned) of object;
  {*
    Fires when list item is about to be removed from the list.
  }
  unaListOnItemBeforeRemoveEvent = procedure(index: int) of object;

  {*
	Data types supported by unaList.
  }
  // NOTE: When adding new types, make sure all cases (dataType) will be aware of them.
  unaListDataType = (uldt_int32, uldt_int64, uldt_ptr, uldt_string, uldt_record, uldt_obj);

  //
  unaListStorage = packed record
    //
    case r_dt: unaListDataType of
      //
      uldt_int32 : (r_32: pInt32Array);
      uldt_int64 : (r_64: pInt64Array);
      uldt_ptr,
      uldt_record,
      uldt_obj,
      uldt_string: (r_ptr: pPtrArray);
  end;

  //
  punaListStringItem = ^unaListStringItem;
  unaListStringItem = packed record
    //
    r_size: uint32;          // size in bytes
    r_data: record end;      // raw string data
  end;


  {*
    This is general purpose list of items.
    Multi-threaded safe.
  }
  unaList = class(unaObject)
  private
    f_count: int;
    f_capacity: unsigned;
    f_timeout: unsigned;
    f_autoFree: bool;
    f_singleThreaded: bool;
    //
    f_list: unaListStorage;
    f_dataItemSize: int;
    //
    f_gate: unaInProcessGate;
    f_dataEvent: unaEvent;
    //
    f_sorted: bool;
    //
    f_onItemRelease: unaListOnItemReleaseEvent;
    f_onItemBeforeRemove: unaListOnItemBeforeRemoveEvent;
    //
    procedure internalSetItem(index: int; value: pointer);
    function getListPtr(): pointer;
    function getListPtrAt(index: int): pointer;
    function getDT(): unaListDataType;
    //
    function compareStr(a, b: pointer): int;
    procedure quickSort(L, R: int);
  protected
    function mapDoFree(doFree: unsigned): bool;
    //
    procedure doSetCapacity(value: unsigned; force: bool = false); virtual;
    {*
      Disposes the item.
    }
    procedure releaseItem(index: int; doFree: unsigned); virtual;
    procedure notifyBeforeRemove(index: int); virtual;
    {*
      Returns true if list was locked by someone (even same thread).
      Could be used only for checking, like the following: "if (not list.isLocked and list.lock()) then ..."
    }
    //function isLocked(): bool;
    {*
      Returns true if there are no items in the list.
      Note, that due to multi-threading issues returned result may be not accurate.
      Use for quick checks only, like status update.
    }
    function isEmpty(): bool;
    //
    function doAdd(item: pointer): int; overload; virtual;
    function doInsert(index: int; item: pointer; brokeSorted: bool = true): int; virtual;
    procedure doSetItem(index: int; item: pointer; brokeSorted: bool = true; doFree: unsigned = 2); overload; virtual;
    //
    procedure doReverse(); virtual;
    function doCopyFrom(list: pointer; listSize: int = -1; copyOperation: unaListCopyOpEnum = unaco_add; startIndex: int = 0): int; virtual;
    //
    {*
      Should return -1 if a < b, +1 if a > b and 0 otherwise.
    }
    function compare(a, b: pointer): int; virtual;
    //
    property list: unaListStorage read f_list;
    property listPtr: pointer read getListPtr;
    property listPtrAt[index: int]: pointer read getListPtrAt;
    property dataItemSize: int read f_dataItemSize;
    {*
      Locks the list. Returns false if lock cannot be set in a timeout period.
      If INFINITE is passed timeOut property will be used instead.
    }
    function lock(timeout: unsigned = INFINITE): bool; virtual;
    {*
	Unlocks the list.
	Must be called after each successful lock()
    }
    procedure unlock(); virtual;
  public
    constructor create(dataType: unaListDataType = uldt_int32; sorted: bool = false);
    procedure BeforeDestruction(); override;
    //
    {$IFDEF DEBUG }
    function lockedByMe(): int;
    {$ENDIF DEBUG }
    //
    {*
      Clears the list. All items will be removed and count will be reset to 0.
    }
    procedure clear(doFree: unsigned = 2; force: bool = false);
    {*
      Adds item to the end of the list.
      Returns list index of inserted item (usually count - 1).
    }
    function add(item: int32): int; overload;
    function add(item: int64): int; overload;
    function add(item: pointer): int; overload;
    {*
      Inserts an item at specified position (index parameter) in the list.
      Does nothing if index is bigger than count.
      Returns index.
    }
    function insert(index: int; item: int32): int; overload;
    function insert(index: int; item: int64): int; overload;
    function insert(index: int; item: pointer): int; overload;
    {*
      Removes an item from the list.
      index specifies the index of item to be removed.
      doFree specifies an action which should be taken if item is object (see unaObjectList):
      <UL>
	<LI>0 -- do not free the object</LI>
	<LI>1 -- free object always</LI>
	<LI>2 -- use the autoFree member of unaObjectList to decide whether to free the object.</LI>
      <UL>
    }
    {*
      Reverses items in the list.
    }
    procedure reverse();
    {*
      Removes item with specified index from the list.
      Returns true if item was removed, or false otherwise.
    }
    function removeByIndex(index: int; doFree: unsigned = 2): bool; overload;
    {*
      Removes specifed item from the list.
      Returns true if item was removed, or false otherwise.
    }
    function removeItem(item: int32): bool; overload;
    function removeItem(item: int64): bool; overload;
    function removeItem(item: pointer; doFree: unsigned = 2): bool; overload;
    {*
      Removes first (removeFirst = true) or last (removeFirst = false) item from the list (if it presents).
      Returns true if item was removed, or false otherwise.
    }
    function removeFromEdge(removeFromBegining: bool = true): bool;
    {*
    }
    function asString(const delimiter: string; treatAsSigned: bool = true; base: unsigned = 10): string;
    {*
      Returns item from the list.
      index specifies the index of item to be returned.
    }
    function get(index: int): pointer;
    {*
      Returns item with specified index as object.
    }
    function getObject(index: int): tObject;
    {*
      Sets item value in the list.
      index specifies the index of item to be set.
      item is value of item. Old item will be freed.
      If old item is object, doFree parameter specifies the action should be taken.
    }
    procedure setItem(index: int; item: int32); overload;
    procedure setItem(index: int; item: int64); overload;
    procedure setItem(index: int; item: pointer; doFree: unsigned = 2); overload;
    function setItem(itemToReplace: pointer; newItem: pointer; doFree: unsigned = 2): unsigned; overload;
    {*
    }
    procedure setCapacity(value: unsigned);
    {*
      Searches the list for specified item value. Returns -1 if no item was found.
    }
    function indexOf(item: int32): int; overload;
    function indexOf(item: int64): int; overload;
    function indexOf(item: pointer): int; overload;
    {*
      Creates a array and copies list items into it.
      <BR />If includeZeroIndexCount is true, the first elemet of array will contain number of items in it.
      <P />Returns size of created array (in bytes).
    }
    function copyTo(out list: pointer; includeZeroIndexCount: bool): int;
    {*
      Returns number of items processed.
      If listSize is -1 list has "zero index count", i.e. number of items is stored as first item of the list.
    }
    function copyFrom(list: pointer; listSize: int = -1; copyOperation: unaListCopyOpEnum = unaco_add; startIndex: int = 0): int; overload;
    function copyFrom(list: unaList; copyOperation: unaListCopyOpEnum = unaco_add; startIndex: int = 0): int; overload;
    {*
      Returns number of items copied.
    }
    function assign(list: unaList): int;
    {*
    }
    function waitForData(timeout: unsigned = 100): bool;
    {*
    }
    function checkDataEvent(): bool;
    {*
      Sorts the list. Override compare() method for custom sorting.
      By default list knows how to sort int32, int64 and string values.
    }
    function sort(): bool;
    //
    {*
      Number of items in the list.
    }
    property count: int read f_count;
    {*
      Set this property to true for lists which know how to free own items, to allow items to be freed by the list.
    }
    property autoFree: bool read f_autoFree write f_autoFree;
    {*
      Default timeout.
    }
    property timeout: unsigned read f_timeout write f_timeout default 1000;
    {*
      Returns list item by it index.
    }
    property item[index: int]: pointer read get write internalSetItem; default;
    //
    {*
      When this property is true list will not use gate to protect internal data in multi-threading access. This may increase performance a little.
    }
    property singleThreaded: bool read f_singleThreaded write f_singleThreaded;
    //
    {*
      Fires when list item is needed to be released. NOTE: item[index] could be nil.
    }
    property onItemRelease: unaListOnItemReleaseEvent read f_onItemRelease write f_onItemRelease;
    {*
      Fires when list item is about to be removed from the list.
    }
    property onItemBeforeRemove: unaListOnItemBeforeRemoveEvent read f_onItemBeforeRemove write f_onItemBeforeRemove;
    //
    property sorted: bool read f_sorted;
    //
    property dataType: unaListDataType read getDT;
  end;

  //
  // -- unaRecordList --
  //
  {*
    List of records (pointers).
    <P />In this list memory pointed by items can be freed automatically (depending on autoFree property value).
  }
  unaRecordList = class(unaList)
  protected
    procedure releaseItem(index: int; doFree: unsigned); override;
  public
    constructor create(autoFree: bool = true; sorted: bool = false);
  end;


  //
  // -- unaIdList --
  //

  {*
    This list is usefull when you wish to access items by their IDs rather than by indexes.
    <BR />It uses internal array to store the ID of every item, so item could be located much faster.
  }
  unaIdList = class(unaList)
  private
    f_allowDI: bool;
    f_idList64: pInt64Array;
    f_idList64Capacity: unsigned;
    //
    procedure setIdListCapacity(value: unsigned; force: bool = false);
  protected
    procedure doSetCapacity(value: unsigned; force: bool); override;
    procedure notifyBeforeRemove(index: int); override;
    {*
      Override this method to provide some implementation of returning the ID of the item.
    }
    function getId(item: pointer): int64; virtual;
    //
    function doAdd(item: pointer): int; override;
    function doInsert(index: int; item: pointer; brokeSorted: bool = true): int; override;
    procedure doSetItem(index: int; item: pointer; brokeSorted: bool = true; doFree: unsigned = 2); override;
    //
    procedure doReverse(); override;
    function doCopyFrom(list: pointer; listSize: int = -1; copyOperation: unaListCopyOpEnum = unaco_add; startIndex: int = 0): int; override;
  public
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    {*
      Returns first item with given ID.
    }
    function itemById(id: int64; startingIndex: int = 0; timeout: unsigned = INFINITE): pointer;
    {*
      Returns index of first item with given ID.
    }
    function indexOfId(id: int64; startingIndex: int = 0): int;
    {*
      Removes item with specified ID.
    }
    function removeById(id: int64; doFree: unsigned = 2): bool;
    {*
      Assigns new Ids for each item in the list. Returns number of items updated.
    }
    function updateIds(): unsigned;
    //
    property allowDuplicateId: bool read f_allowDI write f_allowDI;
  end;

  //
  // -- unaObjectList --
  //

  {*
    List of objects.
    <P />autoFree = true indicates that items will be freed automatically.
  }
  unaObjectList = class(unaList)
  protected
  public
    constructor create(autoFree: bool = true; sorted: bool = false);
  end;


  //
  // -- unaRecordList --
  //
  {*
    List of objects implementing interfaces. Takes care of default ref counting.
    <P />autoFree = true indicates that items will be released automatically.
  }
  unaIntfObjectList = class(unaObjectList)
  protected
    procedure releaseItem(index: int; doFree: unsigned); override;
    function doAdd(item: pointer): int; override;
  public
    {*
      Adds one ref to interfaced object stroed in the list. Returns resulting refcount of an item.
    }
    function itemAddRef(index: int): int;
  end;


  //
  // -- unaStringList --
  //
  {*
    List of strings.
  }
  unaStringList = class(unaRecordList)
  private
    //
    function allocateBuf(const item: string): punaListStringItem;
    function getText(): string;
    procedure setText(const value: string);
    function getValue(const index: string): string;
    procedure setValue(const index, value: string);
    function getName(const index: int): string;
    procedure setName(const index: int; const v: string);
  protected
    //
  public
    constructor create();
    {*
      Adds new string into list.
    }
    function add(const value: string): int;
    {*
      Returns a string by its index.
    }
    function get(index: int): string;
    //
    function insert(index: int; const value: string): int;
    {*
      Performs a case sensitive (if exact is true) or not (if exact is false) search.
      Returns string index or -1 if specified string was not found.
    }
    function indexOf(const value: string; exact: bool = true): int;
    //
    function indexOfValue(const name: string): int;
    {*
      Changes an item with specifiled index in the list.
    }
    procedure setItem(index: int; const item: string);
    {*
      Replaces content of text with data read from a file.
    }
    function readFromFile(const fileName: wString): int;
    //
    property text: string read getText write setText;
    //
    property name[const index: int]: string read getName write setName;
    property value[const index: string]: string read getValue write setValue;
  end;


  //
  // -- unaWideStringList --
  //

  {*
    List of wide strings.
  }
  unaWideStringList = class(unaRecordList)
  private
    //
    function allocateBuf(const item: wString): punaListStringItem;
    function getText(): wString;
    procedure setText(const value: wString);
    function getValue(const index: wString): wString;
    procedure setValue(const index, value: wString);
  protected
    //
  public
    {*
      Adds new string into list.
    }
    function add(const value: wString): int;
    {*
      Returns a string by its index.
    }
    function get(index: int): wString;
    {*
      Performs a case sensitive (if exact is true) or not (if exact is false) search.
      Returns string index or -1 if specified string was not found.
    }
    function indexOf(const value: wString; exact: bool = true): int;
    //
    function indexOfValue(const name: wString): int;
    {*
      Changes an item with specifiled index in the list.
    }
    procedure setItem(index: int; const item: wString);
    {*
      Replaces content of text with data read from a file.
    }
    function readFromFile(const fileName: wString): int;
    //
    property text: wString read getText write setText;
    //
    property values[const index: wString]: wString read getValue write setValue;
  end;


{$IFDEF FPC }
  WIN32_FIND_DATAA = WIN32_FIND_DATA;
{$ENDIF FPC }

  //
  // -- unaFileList --
  //
  {*
    List of file names.
  }
  unaFileList = class(unaRecordList)
  private
    f_root: wString;
    f_mask: wString;
    f_includeSubF: bool;
    //
    f_path: unaStringList;
    f_subPath: unaStringList;
    f_curDir: wString;
    //
    procedure addRecord(data: WIN32_FIND_DATAW); overload;
{$IFNDEF NO_ANSI_SUPPORT }
    procedure addRecord(data: WIN32_FIND_DATAA); overload;
{$ENDIF NO_ANSI_SUPPORT }
  public
    constructor create(const path, mask: wString; includeSubF: bool = false);
    //
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    function refresh(const path, mask: wString; includeSubF: bool = false; clearUp: bool = true; subLevel: int = 0): bool;
    //
    function getFileName(index: int): wString;
    function getFileDate(index: int; dateIndex: int): SYSTEMTIME;
    function getFileSize(index: int): int64;
    function getSubLevel(index: int): unsigned;
    function getAttributes(index: int): unsigned;
    function getPath(index: int): wString;
    function getSubPath(index: int): wString;
    //
    property root: wString read f_root;
    property mask: wString read f_mask;
  end;

  //
  // -- unaRegistry --
  //
  {*
    Registry access class.
  }
  unaRegistry = class(unaObject)
  private
    f_root: HKEY;
    f_key: HKEY;
  public
    constructor create(root: HKEY = HKEY_CURRENT_USER);
    procedure BeforeDestruction(); override;
    //
    procedure close();
    //
    function open(const keyPath: wString; access: unsigned = KEY_READ): int;
    function loadKeyNames(list: unaStringList): int;
    {*
      Returns item value stored in Windows registry.
    }
    function get(const name: wString; var buf: pointer): DWORD; overload;
    function get(const name: wString; buf: pointer; size: DWORD): unsigned; overload;
    function get(const name: wString; def: int): int; overload;
    function get(const name: wString; def: unsigned): unsigned; overload;
    function get(const name: wString; const def: aString): aString; overload;
    {$IFDEF __AFTER_D5__ }
    function get(const name: wString; const def: wString): wString; overload;
    {$ENDIF __AFTER_D5__ }
    {$IFNDEF CPU64 }
    function get(const name: wString; const def: int64): int64; overload;
    {$ENDIF CPU64 }
    {*
      Sets the value of item in Windows registry.
    }
    function setValue(const name: wString; buf: pointer; size: unsigned; keyType: int): int; overload;
    function setValue(const name: wString; value: int): bool; overload;
    function setValue(const name: wString; value: unsigned): bool; overload;
    function setValue(const name: wString; const value: aString): bool; overload;
    {$IFDEF __AFTER_D5__ }
    function setValue(const name: wString; const value: wString): bool; overload;
    {$ENDIF __AFTER_D5__ }
    {$IFNDEF CPU64 }
    function setValue(const name: wString; value: int64): bool; overload;
    {$ENDIF CPU64 }
  end;


const
  //
  c_max_threads	= 1024;	// max number of threads


type
  //
  // -- unaThread --
  //

  unaThread = class;
  {*
    Event used for thread execution.
  }
  unaThreadOnExecuteMethod = function(thread: unaThread): int of object;

  unaThreadManager = class;
  unaThreadStatus = (unatsStopped, unatsStopping, unatsPaused, unatsRunning, unatsBeforeRunning);


  {*
    This is wrapper class over the Windows threads.
    Refer to MSDN documentation for more information about Windows threads.
  }
  unaThread = class(unaObject)
  private
    f_globalThreadIndex: unsigned;
    //
    f_initialActive: bool;
    f_defaultStopTimeout: unsigned;
  {$IFDEF DEBUG }
    f_title: string;
  {$ENDIF DEBUG }
    f_onExecute: unaThreadOnExecuteMethod;
    //
    f_manager: unaThreadManager;
    f_gate: unaInProcessGate;
    //
    f_eventStop: unaEvent;
    f_eventHandleReady: unaEvent;
    f_eventRunning: unaEvent;
    //
    f_sleepEvent: unaEvent;
    //
    function getShouldStop(): bool;
    function getPriority(): int;
    procedure setPriority(value: int);
  protected
    {*
      This method will be called when execution starts in a new thread.
      Override this method in your own threads.
      Return value indicates result code of thread execution.
      You must check the shouldStop property periodically in your code.
      When shouldStop is set to true you this function should return as soon as possible.
    }
    function execute(globalIndex: unsigned): int; virtual;
    {*
      Called just before execute() method.
      Should return true unless it is not desired to continue the execution of a thread.
    }
    function grantStart(): bool; virtual;
    {*
      Called just before shouldStop property will be set to true.
      Should return true unless it is not desired to stop the thread execution.
    }
    function grantStop(): bool; virtual;
    //
    {*
      Called just before execute() method.
    }
    procedure startIn(); virtual;
    {*
      Called just after execute() method.
    }
    procedure startOut(); virtual;
    {*
    }
    function onPause(): bool; virtual;
    {*
    }
    function onResume(): bool; virtual;
    {*
      Notifies the thread should be stopped.
    }
    procedure askStop();
    //
    procedure setDefaultStopTimeout(value: unsigned);
    //
    procedure doSetStatus(value: unaThreadStatus);
  public
    {*
      Creates new thread if active is true. If active is false thread should be created by calling the start() method.
      priority parameter specifies thread priority.
      When autoFree is true thread class will be freed just after thread execution terminates.
    }
    constructor create(active: bool = false; priority: int = THREAD_PRIORITY_NORMAL {$IFDEF DEBUG }; const title: string = ''{$ENDIF});
    //
    procedure AfterConstruction(); override;
    {*
      Destroys the thread. If thread is running, stops it by calling the stop() method.
    }
    procedure BeforeDestruction(); override;
    //
    {*
      Starts the thread.
    }
    function start(timeout: unsigned = 10000): bool;
    {*
      Stops the thread.
    }
    function stop(timeout: unsigned = INFINITE; force: bool = false): bool;
    //
    class function g_shouldStop(threadIndex: unsigned): bool;
    {*
      Suspends thread execution.
    }
    function pause(): bool;
    {*
      Pauses the thread for specified amount of milliseconds.
      Pause may be interrupted by resume(), start(), wakeUp() and stop() mehtods.
      Returns true if pause was interruped, false otherwise.
    }
    function sleepThread(value: unsigned): bool;
    {*
      If thread has entered the sleepThread() state, wakes the thread up, making the speep() method to return True.
      Otherwise simply sets the internal sleep event to signaled state.
    }
    procedure wakeUp();
    {*
      Resumes thread execution.
    }
    function resume(): bool;
    //
    function getStatus(): unaThreadStatus;
    //
    function getHandle(): tHandle;
    //
    function getThreadId(): unsigned;
    //
    {*
      Enters the gate associated with the thread.
    }
    function enter(timeout: unsigned = 1000): bool;
    {*
      Leaves the gate associated with the thread.
    }
    procedure leave();
    //
    class function shouldStopThread(globalIndex: unsigned): bool;
    //
    property globalIndex: unsigned read f_globalThreadIndex;
    {*
      True when thread is (about to be) stopped.
    }
    property shouldStop: bool read getShouldStop;
    {*
      Specifies the priority of the thread.
    }
    property priority: int read getPriority write setPriority;
    {*
      Fires when execution starts in a new thread. See comments for execute() method for details.
    }
    property onExecute: unaThreadOnExecuteMethod read f_onExecute write f_onExecute;
  end;


  //
  // -- unaThreadManager --
  //

  {*
    This class manages one or more threads.
  }
  unaThreadManager = class(unaObject)
  private
    f_master: bool;
    //
    f_threads: unaList;
    f_gate: unaInProcessGate;
    //
    function enumExecute(action: unsigned; param: unsigned = 0): unsigned;
  public
    constructor create(master: bool = true);
    destructor Destroy(); override;
    //
    {*
      Inserts new thread into list.
    }
    function add(thread: unaThread): unsigned;
    function get(index: unsigned): unaThread;
    {*
      Removes thread from the list.
    }
    procedure remove(index: unsigned);
    {*
      Removes all threads from the list.
    }
    procedure clear();
    function getCount(): unsigned;
    {*
      Starts all threads in the list.
    }
    procedure start();
    {*
      Stops all threads in the list.
    }
    function stop(timeout: unsigned = INFINITE): bool;
    procedure pause();
    procedure resume();
  end;


  //
  // -- unaSleepyThread --
  //

  unaSleepyThread = class(unaThread)
  private
    f_minCPU: int64;
    f_maxCPU: int64;
    f_cpuUsage: unsigned;
    f_stones: unsigned;
    //
    f_mem: pointer;
    //
    procedure dummyJob();
    //
  protected
    function execute(globalIndex: unsigned): int; override;
  public
    constructor create(active: bool = false);
    //
    property cpu: unsigned read f_cpuUsage;
    property stones: unsigned read f_stones;
  end;


  //
  // -- unaAbstractTimer --
  //

  unaAbstractTimer = class;

  onTimerEvent = procedure(sender: tObject) of object;

  {*
    This is an abstract timer. Do not create instances of this class.
  }
  unaAbstractTimer = class(unaObject)
  private
    f_interval: unsigned;
    f_isRunning: bool;
    f_isPaused: bool;
  {$IFDEF DEBUG }
    f_title: string;
  {$ENDIF DEBUG }
    //
    f_onTimerEvent: onTimerEvent;
    f_gate: unaInProcessGate;
    //
    procedure doSetInterval(value: unsigned);
  protected
    procedure timer(); virtual;
    procedure changeInterval(var newValue: unsigned); virtual;
    function doStart(): bool; virtual; abstract;
    procedure doStop(); virtual;
    procedure doTimer();
  public
    constructor create(interval: unsigned = 1000{$IFDEF DEBUG }; const title: string = ''{$ENDIF});
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    procedure start();
    procedure stop();
    procedure pause();
    procedure resume();
    //
    function isRunning(): bool;
    function enter(timeout: unsigned): bool;
    procedure leave();
    //
    property interval: unsigned read f_interval write doSetInterval;
    property onTimer: onTimerEvent read f_onTimerEvent write f_onTimerEvent;
  {$IFDEF DEBUG }
    property title: string read f_title;
  {$ENDIF DEBUG }
  end;


  //
  // -- unaTimer --
  //

  {*
    Message-based timer. Message queue should be checked periodically for this timer to work correctly.
  }
  unaTimer = class(unaAbstractTimer)
  private
    f_timer: unsigned;
  protected
    function doStart(): bool; override;
    procedure doStop(); override;
  public
  end;


  //
  // -- unaThreadTimer --
  //

  unaThreadedTimer = class;

  unaTimerThread = class(unaThread)
  private
    f_timer: unaThreadedTimer;
  protected
    function execute(globalIndex: unsigned): int; override;
  public
    constructor create(timer: unaThreadedTimer; active: bool = false; priority: int = THREAD_PRIORITY_TIME_CRITICAL);
  end;


  {*
    Base clss: thread wrapper for thread-based timers. Do not use this class directly.
  }
  unaThreadedTimer = class(unaAbstractTimer)
  private
    f_active: bool;
    f_thread: unaThread;
    //
    function getPriority(): unsigned;
    procedure setPriority(value: unsigned);
  protected
    procedure execute(thread: unaTimerThread); virtual; abstract;
    //
    function doStart(): bool; override;
    procedure doStop(); override;
  public
    constructor create(interval: unsigned; active: bool = false; priority: int = THREAD_PRIORITY_TIME_CRITICAL);
    destructor Destroy(); override;
    procedure AfterConstruction(); override;
    //
    property priority: unsigned read getPriority write setPriority;
  end;


  //
  // -- unaThreadTimer --
  //

  {*
    This timer uses thread to tick periodically.
  }
  unaThreadTimer = class(unaThreadedTimer)
  protected
    procedure execute(thread: unaTimerThread); override;
  public
  end;


  //
  // -- unaWaitableTimer --
  //

  {*
    This timer uses waitable timers to tick periodically.
    <BR /><STRONG>NOTE</STRONG>: Waitable timers were introduced since Windows 98.
  }
  unaWaitableTimer = class(unaThreadedTimer)
  private
    f_firstTime: bool;
    f_handle: tHandle;
  protected
    function doStart(): bool; override;
    procedure doStop(); override;
    procedure execute(thread: unaTimerThread); override;
  public
    constructor create(interval: unsigned = 1000);
    destructor Destroy(); override;
  end;


  //
  // -- unaRandomGenThread --
  //

  {*
    This thread produces random values from HPRC and other hard-predictable sources.
  }
  unaRandomGenThread = class(unaThread)
  private
    f_nextValue: unsigned;
    f_nextValueBitsValid: unsigned;	// number of valid bits in f_nextValue (0..32 or 0..64)
    f_nextValueBitsMax: unsigned;	// max number of bits in f_nextValue (0..32 or 0..64)
    f_timeMark: int64;
    //
    f_waitTime: int64;		// time spend when waiting for last value
    f_waitTimeTotal: int64;	// total time spend when waiting for random values
    f_pseudoFeeds: int64;	// number of pseudo-generated values returned
    //
    f_values: unaList;
    f_aheadGenSize: unsigned;
    //
    function getValuesInCacheNum(): unsigned;
  protected
    procedure startIn(); override;
    procedure startOut(); override;
    function execute(globalId: unsigned): int; override;
  public
    constructor create(aheadGenSize: unsigned = 1000; active: bool = true; priority: int = THREAD_PRIORITY_LOWEST);
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    destructor Destroy(); override;
    //
    {*
      Returns random value in range 0 to upperLimit - 1.

      @param upperLimit Max value to be returned by function. Default is $FFFFFFFF.
      @param maxTimeout Time (ms) to wait for new value if none is ready. Default is -1, which equals 10 seconds.

      @return Random value or high(unsigned) in case of some internal error or if timeout had occured and maxTimeout = -1 (default).
    }
    function random(upperLimit: uint32 = $FFFFFFFF; maxTimeout: int = -1): uint32;
    {*
      Feeds a generator with new randmon value. Does nothing if ahead gen size is already reached.
      Returns true if value was added, or false otherwise.
    }
    function feed(value: unsigned): bool;
    {*
      Returns number of values in ahead-generated list.
    }
    property valuesReady: unsigned read getValuesInCacheNum;
    //
    property waitTime: int64 read f_waitTime;
    property waitTimeTotal: int64 read f_waitTimeTotal;
    property pseudoFeeds: int64 read f_pseudoFeeds;
  end;


  //
  // -- unaIniAbstractStorage --
  //

  {*
    Manages values stored in "INI" format.
    <BR>NOTE: This class is abstract, do not create instances of it.
  }
  unaIniAbstractStorage = class(unaObject)
  private
    f_section: wString;
    //
    f_gate: unaInProcessGate;
    f_lockTimeout: unsigned;
    //
    function getUnsigned(const key: string; defValue: unsigned = 0): unsigned; overload;
    function getInt(const key: string; defValue: int = 0): int; overload;
    function getInt64(const key: string; defValue: int64 = 0): int64; overload;
    function getBool(const key: string; defValue: bool = false): bool; overload;
    //
    function getUnsigned(const section, key: string; defValue: unsigned = 0): unsigned; overload;
    function getInt(const section, key: string; defValue: int = 0): int; overload;
    function getInt64(const section, key: string; defValue: int64 = 0): int64; overload;
    function getBool(const section, key: string; defValue: bool = false): bool; overload;
    function getStringSectionKey(const section, key: string; const defValue: string = ''): string; overload;
    //
    function getSection(): string;
    procedure setSection(const section: string);
  protected
    function getStringValue(const key: string; const defValue: string = ''): string; virtual; abstract;
    procedure setStringValue(const key: string; const value: string); virtual; abstract;
    //
    function getAsString(): string; virtual; abstract;
    procedure setAsString(const value: string); virtual; abstract;
    //
    function doGetSectionAsText(const sectionName: string): string; virtual; abstract;
    function doSetSectionAsText(const sectionName, value: string): bool; virtual; abstract;
  public
    constructor create(const section: string = 'settings'; lockTimeout: unsigned = 1000);
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    function get(const key: string; defValue: int = 0): int; overload;
    {$IFNDEF CPU64 }
    function get(const key: string; defValue: int64 = 0): int64; overload;
    {$ENDIF CPU64 }
    function get(const key: string; defValue: unsigned = 0): unsigned; overload;
    function get(const key: string; defValue: boolean = false): bool; overload;
    function get(const key: string; const defValue: string = ''): string; overload;
{$IFDEF __BEFORE_DC__ }
  {$IFDEF __AFTER_D5__ }
    function get(const key: string; const defValue: wString = ''): wString; overload;
  {$ENDIF __AFTER_D5__ }
{$ELSE }
    function get(const key: string; const defValue: aString = ''): aString; overload;
{$ENDIF __BEFORE_DC__ }
    //
    // -- routines for C++Builder
    function get_int     (const key: string; defValue: int = 0): int;
    function get_int64   (const key: string; defValue: int64 = 0): int64;
    function get_unsigned(const key: string; defValue: unsigned = 0): unsigned;
    function get_bool    (const key: string; defValue: bool = false): bool;
    function get_string  (const key: string; const defValue: string = ''): string;
    // --
    function get(const section, key: string; defValue: int): int; overload;
    {$IFNDEF CPU64 }
    function get(const section, key: string; defValue: int64): int64; overload;
    {$ENDIF CPU64 }
    function get(const section, key: string; defValue: unsigned): unsigned; overload;
    function get(const section, key: string; defValue: boolean): bool; overload;
    function get(const section, key: string; const defValue: string): string; overload;
{$IFDEF __BEFORE_DC__ }
  {$IFDEF __AFTER_D5__ }
    function get(const section, key: string; const defValue: wString): wString; overload;
  {$ENDIF __AFTER_D5__ }
{$ELSE }
    function get(const section, key: string; const defValue: aString): aString; overload;
{$ENDIF __BEFORE_DC__ }
    //
    procedure setValue(const key: string; value: int); overload;
    {$IFNDEF CPU64 }
    procedure setValue(const key: string; value: int64); overload;
    {$ENDIF CPU64 }
    procedure setValue(const key: string; value: unsigned); overload;
    procedure setValue(const key: string; value: boolean); overload;
    procedure setValue(const key: string; const value: string); overload;
{$IFDEF __BEFORE_DC__ }
  {$IFDEF __AFTER_D5__ }
    procedure setValue(const key: string; const value: wString); overload;
  {$ENDIF __AFTER_D5__ }
{$ELSE }
    procedure setValue(const key: string; const value: aString); overload;
{$ENDIF __BEFORE_DC__ }
    // -- routines for C++Builder
    procedure set_int     (const key: string; value: int);
    procedure set_int64   (const key: string; value: int64);
    procedure set_unsigned(const key: string; value: unsigned);
    procedure set_bool    (const key: string; value: bool);
    procedure set_string  (const key: string; const value: string);
    // --
    procedure setValue(const section, key: string; value: int); overload;
    {$IFNDEF CPU64 }
    procedure setValue(const section, key: string; value: int64); overload;
    {$ENDIF CPU64 }
    procedure setValue(const section, key: string; value: unsigned); overload;
    procedure setValue(const section, key: string; value: boolean); overload;
    procedure setValue(const section, key: string; const value: string); overload;
{$IFDEF __BEFORE_DC__ }
  {$IFDEF __AFTER_D5__ }
    procedure setValue(const section, key: string; const value: wString); overload;
  {$ENDIF __AFTER_D5__ }
{$ELSE }
    procedure setValue(const section, key: string; const value: aString); overload;
{$ENDIF __BEFORE_DC__ }
    //
    {*
        Timeout is in milliseconds.
    }
    function waitForValue(const key, value: string; timeout: int): bool;
    //
    function getSectionAsText(const sectionName: string = ''): string;
    function setSectionAsText(const sectionName: string; const value: string): bool; overload;
    function setSectionAsText(const value: string): bool; overload;
    //
    function enter(const section: string; out sectionSave: string; timeout: unsigned = 0): bool; overload;
    function enter(const section: string = ''; timeout: unsigned = 0): bool; overload;
    procedure leave(const sectionSave: string = '');
    //
    property section: string read getSection write setSection;
    property lockTimeout: unsigned read f_lockTimeout write f_lockTimeout;
    {*
      Use carefully, string is created every time this property is touched.
    }
    property asString: string read getAsString write setAsString;
  end;


  //
  // -- unaIniFile --
  //
  {*
    Manages values stored in Windows INI files.
  }
  unaIniFile = class(unaIniAbstractStorage)
  private
    f_fileName: wString;
    //
    procedure setFileName(const value: wString);
    procedure fixFilePath();
  protected
    function getStringValue(const key: string; const defValue: string = ''): string; override;
    procedure setStringValue(const key: string; const value: string); override;
    //
    function getAsString(): string; override;
    procedure setAsString(const value: string); override;
    //
    function doGetSectionAsText(const sectionName: string): string; override;
    function doSetSectionAsText(const sectionName, value: string): bool; override;
  public
    constructor create(const fileName: wString = ''; const section: string = 'settings'; lockTimeout: unsigned = 1000; checkFilePath: bool = true);
    procedure AfterConstruction(); override;
    //
    property fileName: wString read f_fileName write setFileName;
  end;


  //
  // -- unaIniMemorySection --
  //
  {*
    Manages values stored in Windows INI files.
  }
  unaIniMemorySection = class(unaObject)
  private
    f_name: string;
    f_keys: unaStringList;
    f_values: unaStringList;
  public
    constructor create(const name: string);
    //
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    procedure addKeyValue(const key, value: string);
    //
    property name: string read f_name;
  end;


  //
  // -- unaIniMemory --
  //
  {*
    Manages values stored in memory in INI format.
  }
  unaIniMemory = class(unaIniAbstractStorage)
  private
    f_sections: unaObjectList;
    //
    procedure parseMemory(memory: paChar; size: unsigned);
    function getSection(const name: string; allowCreation: bool): unaIniMemorySection;
  protected
    function getStringValue(const key: string; const defValue: string = ''): string; override;
    procedure setStringValue(const key: string; const value: string); override;
    //
    function getAsString(): string; override;
    procedure setAsString(const value: string); override;
    //
    function doGetSectionAsText(const sectionName: string): string; override;
    function doSetSectionAsText(const sectionName, value: string): bool; override;
  public
    constructor create(memory: pointer = nil; size: unsigned = 0; const section: string = 'settings'; lockTimeout: unsigned = 1000);
    procedure BeforeDestruction(); override;
    //
    procedure loadFrom(const fileName: wString);
    procedure saveTo(const fileName: wString);
  end;


  //
  // -- unaAbstractStream --
  //

  unaAbstractStreamClass = class of unaAbstractStream;

  {*
    Simple First In First Out (FIFO) stream. It is multi-threaded safe, so you can use it from several threads without any special care.
  }
  unaAbstractStream = class(unaObject)
  private
    f_summarySize: int;
    f_isValid: bool;
    f_pos: int;
    f_maxSize: int;
    //
    f_dataEvent: unaEvent;
  {$IFDEF DEBUG }
    f_title: string;
  {$ENDIF DEBUG }
    f_lockTimeout: unsigned;
    //
    f_gate: unaInProcessGate;
    //
    function getIsEmpty: bool;
  protected
    function seek(position: int; fromBeggining: bool = true): int; overload; virtual;
    function seekD(delta: int): int; overload; virtual;
    function getPosition(): int; virtual;
    function remove2(size: int): int; virtual;
    function clear2(): unaAbstractStream; virtual;
    function write2(buf: pointer; size: int): int; virtual;
    function read2(buf: pointer; size: int; remove: bool = true): int; virtual; abstract;
    //
    function getSize2(): int; virtual;
    function getAvailableSize2(): int; virtual;
  public
    constructor create(lockTimeout: unsigned = 1000{$IFDEF DEBUG }; const title: string = ''{$ENDIF DEBUG }); virtual;
    procedure AfterConstruction(); override;
    destructor Destroy(); override;
    //
    function clear(): unaAbstractStream;
    function waitForData(timeout: unsigned = 1000): bool;
    function remove(size: int): int;
    //
    function readFrom(const fileName: wString; offset: int = 0): int; overload;
    function readFrom(source: unaAbstractStream): int; overload;
    //
    function write(buf: pointer; size: int): int; overload;
    function write(value: boolean): int; overload;
    function write(value: byte): int; overload;
    function write(value: word): int; overload;
    function write(value: int): int; overload;
    function write(value: unsigned): int; overload;
    function write(const value: aString): int; overload;
    //
    function read(buf: pointer; size: int; remove: bool = true): int; overload;
    function read(def: boolean; remove: bool = true): bool; overload;
    function read(def: byte; remove: bool = true): byte; overload;
    function read(def: word; remove: bool = true): word; overload;
    function read(def: int; remove: bool = true): int; overload;
    function read(def: unsigned; remove: bool = true): unsigned; overload;
    function read(const def: aString; remove: bool = true): aString; overload;
    //
    function writeTo(const fileName: wString; append: bool = true; size: int = 0): int; overload;
    function writeTo(dest: unaAbstractStream): int; overload;
    class function copyStream(source, dest: unaAbstractStream): int;
    //
    function getSize(): int;
    function getAvailableSize(): int;
    //
    function enter(timeout: unsigned = INFINITE{$IFDEF DEBUG }; const masterName: string = ''{$ENDIF DEBUG }): bool;
    procedure leave();
  {$IFDEF DEBUG }
    property gate: unaInProcessGate read f_gate;
  {$ENDIF DEBUG }
    //
    property isValid: bool read f_isValid;
    property isEmpty: bool read getIsEmpty;
  {$IFDEF DEBUG }
    property title: string read f_title write f_title;
  {$ENDIF DEBUG }
    property lockTimeout: unsigned read f_lockTimeout write f_lockTimeout default 1000;
    //
    property dataEvent: unaEvent read f_dataEvent;
    //
    property maxSize: int read f_maxSize write f_maxSize default 0;
  end;


  //
  // -- unaStreamChunk --
  //
  unaStreamChunk = class(unaObject)
  private
    f_buf: pointer;
    f_bufSize: int;
    f_dataSize: int;
    f_offset: int;
  public
    constructor create(buf: pointer; size: int);
    destructor Destroy(); override;
    //
    function getSize(): int;
    function read(buf: pointer; size: int; remove: bool = true): int;
    procedure newData(buf: pointer; size: int);
  end;


  //
  // -- unaMemoryStream --
  //

  {*
    This stream is stored in memory. This implementation does not support seeking.
  }
  unaMemoryStream = class(unaAbstractStream)
  private
    f_chunks: unaObjectList;
    f_emptyChunks: unaObjectList;
    f_maxCacheSize: unsigned;
  protected
    function seek(position: int; fromBeggining: bool = true): int; overload; override;
    function seekD(delta: int): int; overload; override;
    function getPosition(): int; override;
    function remove2(size: int): int; override;
    function clear2(): unaAbstractStream; override;
    //
    function read2(buf: pointer; size: int; remove: bool = true): int; override;
    function write2(buf: pointer; size: int): int; override;
    function getAvailableSize2(): int; override;
  public
    procedure AfterConstruction(); override;
    destructor Destroy(); override;
    //
    function getCrc32(): unsigned;
    //
    function getFirstChunkSize(): int;
    //
    property maxCacheSize: unsigned read f_maxCacheSize write f_maxCacheSize default 10;
  end;


  {*
    This stream is stored in memory. It does support seeking.
  }
  unaMemoryData = class(unaAbstractStream)
  private
    f_data: pArray;
  protected
    function read2(buf: pointer; size: int; remove: bool = true): int; override;
    function write2(buf: pointer; size: int): int; override;
    function remove2(size: int): int; override;
  public
    constructor createData(data: pointer; size: int);
    procedure BeforeDestruction(); override;
    //
    property data: pArray read f_data;
  end;


  //
  // -- unaFileStream --
  //

  {*
    This stream is stored in a file.
  }
  unaFileStream = class(unaAbstractStream)
  private
    f_handle: tHandle;
    f_fileName: wString;
    f_fileOffset: unsigned;
    f_access: unsigned;
    f_shareMode: unsigned;
    f_loop: bool;
    f_fileFlags: unsigned;
  protected
    function clear2(): unaAbstractStream; override;
    //
    function read2(buf: pointer; size: int; remove: bool = true): int; override;
    function write2(buf: pointer; size: int): int; override;
    {*
      Returns size of file.
    }
    function getSize2(): int; override;
    {*
      Returns number of bytes you can read from the file from current position.
    }
    function getAvailableSize2(): int; override;
  public
    procedure AfterConstruction(); override;
    constructor createStream(const fileName: wString; access: unsigned = GENERIC_READ + GENERIC_WRITE; shareMode: unsigned = FILE_SHARE_READ + FILE_SHARE_WRITE; loop: bool = false; fileFlags: unsigned = FILE_ATTRIBUTE_NORMAL);
    destructor Destroy(); override;
    //
    function initStream(const fileName: wString; access: unsigned = GENERIC_READ + GENERIC_WRITE; shareMode: unsigned = FILE_SHARE_READ + FILE_SHARE_WRITE; loop: bool = false; fileFlags: unsigned = FILE_ATTRIBUTE_NORMAL): bool;
    function seek(position: int; fromBeggining: bool = true): int; overload; override;
    function seekD(delta: int): int; overload; override;
    function getPosition(): int; override;
    //
    procedure close();
    //
    property fileName: wString read f_fileName;
    {*
      When reading beyond the end of file, set this property is true, to wrap at 0 offset.
    }
    property loop: bool read f_loop write f_loop;
  end;


  //
  // -- unaResourceStream --
  //

  {*
    This stream is stored in resource.
  }
  unaResourceStream = class(unaAbstractStream)
  private
    f_name: wString;
    f_resType: pwChar;
    f_instance: hModule;
    //
    f_resource: hRSRC;
    f_global: hGLOBAL;
    f_data: pointer;
  protected
    function read2(buf: pointer; size: int; remove: bool = true): int; override;
    function write2(buf: pointer; size: int): int; override;
  public
    constructor createRes(const name: wString; resType: pwChar = RT_RCDATAW; instance: hModule = 0);
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    function find(const name: wString; resType: pwChar = RT_RCDATAW; instance: hModule = 0): int;
    //
    function lock(): int;
    procedure unlock();
    //
    property data: pointer read f_data;
  end;


  //
  // -- unaMappedMemory --
  //

  {*
    This is wrapper class for the Windows mapped memory mechanism.
  }
  unaMappedMemory = class(unaObject)
  private
    f_doOpen: bool;
    f_access: DWORD;
    f_canCreate: bool;
    f_handle: tHandle;
    f_name: wString;
    //f_data: pArray;
    f_size64: int64;
    f_fileHandle: tHandle;
    f_mapFlags: unsigned;
    f_allocGran: unsigned;
    f_header: pointer;
    f_headerSize: int;
    //
    f_openViews: unaList;
    //
    procedure setSize(value: int64);
  protected
    function open2(access: DWORD = PAGE_READWRITE): bool; virtual;
    procedure close2(); virtual;
    procedure doSetNewSize(newValue: int64); virtual;
  public
    constructor create(const name: wString; size64: int64 = 0; access: DWORD = PAGE_READWRITE; doOpen: bool = true; canCreate: bool = true);
    procedure AfterConstruction(); override;
    procedure BeforeDestruction(); override;
    //
    function open(access: DWORD = PAGE_READWRITE): bool;
    procedure close();
    //
    function read(offs: int64; buf: pointer; sz: unsigned): unsigned;
    function write(offs: int64; buf: pointer; sz: unsigned): unsigned;
    function flush(): bool;
    //
    function mapView(offset: int64; reqSize: unsigned; out subOfs: int): pointer;
    function mapViewAll(): pointer;
    function mapHeader(size: int = -1): pointer;	// maps <size> bytes at offset 0 (allocGran bytes if size = -1, default)
    function unmapView(baseAddr: pointer): bool;
    //
    //property data: pArray read f_data;
    property size64: int64 read f_size64 write setSize;
    property handle: tHandle read f_handle;
    property allocGran: unsigned read f_allocGran;
  end;


  //
  // -- unaMappedFile --
  //

  {*
    This is wrapper class for the Windows mapped files mechanism.
  }
  unaMappedFile = class(unaMappedMemory)
  private
    f_fileName: wString;
  protected
    function open2(access: DWORD = PAGE_READWRITE): bool; override;
    procedure close2(); override;
  public
    constructor create(const fileName: wString; access: DWORD = PAGE_READWRITE; doOpen: bool = true; size: int = 0);
    //
    function openFile(const fileName: wString; access: DWORD = PAGE_READWRITE; size: int = 0): bool;
    //
    function ensureSize(value: int64): bool;
  end;


  //
  // -- unaConsoleApp --
  //

  {*
    This class encapsulates basic Windows console application.
  }
  unaConsoleApp = class(unaThread)
  private
    f_ok: bool;
    f_consoleInfo: CONSOLE_SCREEN_BUFFER_INFO;
    f_inHandle: tHandle;
    f_outHandle: tHandle;
    //
    function getConsoleInfo(): pConsoleScreenBufferInfo;
  protected
    f_executeComplete: bool;
    //
    {*
      You can override this method to perform additional initialization.
      <BR />If this method returns false the application will not be started.
    }
    function doInit(): bool; virtual;
    {*
      Processes Windows messages until the thread terminates.
    }
    function execute(globalIndex: unsigned): int; override;
  public
    {*
      Creates console application class. You can specify caption, icon and text attributes to be used in the console box initialization.
    }
    constructor create(const caption: wString = ''; icon: hIcon = 0; textAttribute: unsigned = FOREGROUND_BLUE or FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY);
    destructor Destroy(); override;
    procedure AfterConstruction(); override;
    //
    {*
      Starts the application thread. This method returns only when user press the Enter key.
    }
    procedure run(enterStop: bool = true);
    //
    property consoleInfo: pConsoleScreenBufferInfo read getConsoleInfo;
    property outputHandle: tHandle read f_outHandle;
    property inputHandle: tHandle read f_inHandle;
  end;

{*
	Locks a list if it is not nil and contains at least one element.
	list.Unlock() must be called if this function returns true.

	@param list List to be locked.
	@param timeout Timeout for locking gate.

	@return True if list contains at least one element and was locked, or False if list is nil, empty or timeout expired.
}
function lockNonEmptyList(list: unaList; timeout: unsigned = INFINITE): bool;
{*
	Lock a list.
}
function lockList(list: unaList; timeout: unsigned = INFINITE): bool;
{*
	Unlocks the list locked by lockNonEmptyList.
}
procedure unlockList(list: unaList);

{*
	Returns true if files' content is the same. Uses mapped file class.

	@param fileName1 Name of first file.
	@param fileName2 Name of second file.

	@return True if files are same.
}
function sameFiles(const fileName1, fileName2: wString): bool;

{*
	Returns size of files in specifed folder (and optionally all subfolders).

	@param folder Path.
	@param includeSubFolders Process files in subfolders (default is True).

	@return Total size of all files.
}
function getFolderSize(const folder: wString; includeSubFolders: bool = true): int64;


implementation


uses
  Messages;


{ unaObject }

var
  g_acquire: unaAcquireType;
  g_acquireThreadID: DWORD;

// --  --
function unaObject.acquire(timeout: int; fsn: bool): bool;
var
  ct: DWORD;
begin
  ct := GetCurrentThreadId();
  //
  if (fsn or (nil = self)) then begin
    //
    result := acquire32Try(g_acquire, timeout);
    if (result and (0 = g_acquireThreadID)) then
      g_acquireThreadID := ct;
  end
  else begin
    //
    if (f_acqThreadID = ct) then begin
      //
      acquire32(f_acqObj, false);	// just increase the count
      result := true;
    end
    else
      result := acquire32Try(f_acqObj, timeout);
    //
    if (result) then
      f_acqThreadID := ct;
  end;
end;

// --  --
procedure unaObject.acquire();
begin
  if (nil = self) then begin
    //
    acquire32(g_acquire, false);
    if (0 = g_acquireThreadID) then
      g_acquireThreadID := GetCurrentThreadId();
  end
  else
    acquire32(f_acqObj, false);
end;

// --  --
class procedure unaObject.acquireStatic();
var
  obj: unaObject;
begin
  obj := nil;
  obj.acquire();	// hm.. looks weird, I know
end;

// --  --
class function unaObject.acquireStatic(timeout: int): bool;
var
  obj: unaObject;
begin
  obj := nil;
  result := obj.acquire(timeout);	// hm.. looks weird, I know
end;

// --  --
procedure unaObject.AfterConstruction();
begin
  f_destroyed := false;
  //
  {$IFDEF LOG_UNACLASSES_INFOS }
  if (not f_inheritedCreateWasCalled) then
    logMessage(self._classID + '.AfterConstruction() - inherited constructor was not called!');
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
  inherited;
end;

// --  --
procedure unaObject.BeforeDestruction();
begin
  inherited;
  //
  f_destroyed := true;
  //
  if (0 < f_acqObj) then
    // looks like object is destroying inside own lock, so we acquire global obj here
    acquire(0, true);
end;

// --  --
constructor unaObject.create();
begin
  {$IFDEF LOG_UNACLASSES_INFOS }
  f_inheritedCreateWasCalled := true;
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
  inherited create();
end;

// --  --
function unaObject.getClassID(): string;
begin
  {$IFDEF DEBUG }
  result := className + '[@0x' + int2str(UIntPtr(self), 16) + ']';
  {$ELSE }
  result := '';
  {$ENDIF DEBUG }
end;

// --  --
function unaObject.getThis(): unaObject;
begin
  result := self;	// self is this! :)
end;

// --  --
function unaObject.release(): bool;
var
  sameID: bool;
  ct: DWORD;
begin
  ct := GetCurrentThreadId();
  //
  sameID := ( (0 <> g_acquireThreadID) and (g_acquireThreadID = ct) );
  if (sameID or (nil = self)) then begin
    //
    result := release32(g_acquire);
    if (result and sameID) then
      g_acquireThreadID := 0;
  end
  else begin
    //
    result := release32(f_acqObj);
    if (result and (f_acqThreadID = ct)) then
      f_acqThreadID := 0;
  end;
end;


{ unaEvent }

// --  --
constructor unaEvent.create(manualReset, initialState: bool; const name: wString);
begin
  inherited create();
  //
  f_name := name;
  //
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    f_handle := CreateEventW(nil, manualReset, initialState, pwChar(f_name))
{$IFNDEF NO_ANSI_SUPPORT }
  else
    f_handle := CreateEventA(nil, manualReset, initialState, paChar(aString(f_name)));
{$ENDIF NO_ANSI_SUPPORT }
  ;
end;

// --  --
destructor unaEvent.Destroy();
begin
  inherited;
  //
  CloseHandle(f_handle);
end;

// --  --
procedure unaEvent.setState(signaled: bool);
begin
  if (signaled) then
    SetEvent(f_handle)
  else
    ResetEvent(f_handle);
end;

// --  --
function unaEvent.waitFor(timeout: unsigned): bool;
begin
  result := waitForObject(f_handle, timeout);
end;


{ unaAbstractGate }

// --  --
constructor unaAbstractGate.create({$IFDEF DEBUG}const title: string{$ENDIF});
begin
{$IFDEF DEBUG}
  f_title := title;
{$ENDIF DEBUG }
  //
{$IFDEF UNA_GATE_PROFILE }
  f_profileIndexEnter2 := profileMarkRegister(self._classID + '(' + title + ').Enter', UIntPtr(self));
  f_profileIndexLeave2 := profileMarkRegister(self._classID + '(' + title + ').Leave', UIntPtr(self));
{$ENDIF UNA_GATE_PROFILE }
  //
  inherited create();
end;

// --  --
function unaAbstractGate.enter(timeout: unsigned{$IFDEF DEBUG }; const masterName: string{$ENDIF DEBUG }): bool;
{$IFDEF DEBUG }
var
{$ELSE }
  {$IFDEF UNA_GATE_DEBUG_TIMEOUT }
var
  {$ENDIF UNA_GATE_DEBUG_TIMEOUT }
{$ENDIF DEBUG }

{$IFDEF UNA_GATE_DEBUG_TIMEOUT }
  mark: int64;
{$ENDIF}
{$IFDEF DEBUG }
  owner: unsigned;
  TLC, RLC: int;
{$ENDIF DEBUG }
begin
{$IFDEF UNA_GATE_PROFILE }
  profileMarkEnter(f_profileIndexEnter2);
{$ENDIF UNA_GATE_PROFILE }
  //
  if (nil = self) then begin
    //
    {$IFDEF LOG_UNACLASSES_ERRORS }
    logMessage('[' + masterName + '].enter(' + int2str(timeout) + ') - self is nil!');
    {$ENDIF LOG_UNACLASSES_ERRORS }
    //
    result := false;
    exit;
  end;
  //
  {$IFDEF LOG_UNACLASSES_INFOS }
  if (INFINITE = timeout) then
    logMessage(self._classID + '[' + masterName + '].enter(' + int2str(timeout) + ') - INFINITE..');
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
{$IFDEF UNA_GATE_DEBUG_TIMEOUT }
  mark := timeMark();
{$ENDIF UNA_GATE_DEBUG_TIMEOUT }
  //
{$IFDEF DEBUG }
  if (self is unaInProcessGate) then begin
    //
    owner := (self as unaInProcessGate).owningThreadId;
    TLC := -1;//(self as unaInProcessGate).tryLockCount;
    RLC := (self as unaInProcessGate).recursionLockCount;
  end
  else begin
    //
    owner := unsigned(-1);
    TLC := -1;
    RLC := -1;
  end;
{$ENDIF DEBUG }
  //
  try
    result := gateEnter(timeout{$IFDEF DEBUG}, masterName{$ENDIF});
  except
    result := false;
  end;
  //
{$IFDEF UNA_GATE_DEBUG_TIMEOUT }
  logMessage({$IFDEF DEBUG}'(' + masterName + ')' + {$ENDIF}'.enter(' + int2str(timeout) + ') takes ' + int2str(timeElapsed64(mark), 10, 3));
{$ENDIF UNA_GATE_DEBUG_TIMEOUT }
  //
  if (not result and (1 < timeout)) then begin
    //
    {$IFDEF LOG_UNACLASSES_INFOS }
    logMessage(self._classID + '[' + masterName + '].enter(timeout=' + int2str(timeout) + ' ms) - gate is locked by [' + int2str(owner, 16) + ']; RLC=' + int2str(RLC) + '; TLC=' + int2str(TLC));
    {$ENDIF LOG_UNACLASSES_INFOS }
  end;
  //
{$IFDEF UNA_GATE_PROFILE }
  profileMarkLeave(f_profileIndexEnter2);
{$ENDIF UNA_GATE_PROFILE }
end;

// --  --
function unaAbstractGate.gateEnter(timeout: unsigned{$IFDEF DEBUG}; const masterName: string{$ENDIF}): bool;
begin
{$IFDEF DEBUG }
  f_masterName := masterName;
{$ENDIF DEBUG }
  result := true;
end;

// --  --
procedure unaAbstractGate.gateLeave();
begin
{$IFDEF DEBUG}
  f_masterName := '';
{$ENDIF DEBUG }
  f_isBusy := false;
end;

// --  --
procedure unaAbstractGate.leave();
begin
{$IFDEF UNA_GATE_PROFILE }
  profileMarkEnter(f_profileIndexLeave2);
{$ENDIF UNA_GATE_PROFILE }
  //
  gateLeave();
{$IFDEF UNA_GATE_PROFILE }
  profileMarkLeave(f_profileIndexLeave2);
{$ENDIF UNA_GATE_PROFILE }
end;


{ unaOutProcessGate }

// --  --
function unaOutProcessGate.checkDeadlock(timeout: unsigned; const name: string): bool;
var
  ct: tHandle;
begin
  // simple deadlock check (seems not working properly / 10 Feb 2002)
  ct := GetCurrentThread();
  //
  if ((INFINITE = timeout) and f_inside and (f_masterThread = ct)) then begin
    //
    result := true;
    {$IFDEF LOG_UNACLASSES_INFOS }
    logMessage(self._classID + '.enter(' + name + ') - potential deadlock');
    {$ENDIF LOG_UNACLASSES_INFOS }
  end
  else
    result := false;
end;

// --  --
constructor unaOutProcessGate.create({$IFDEF DEBUG}const title: string{$ENDIF});
begin
  inherited create({$IFDEF DEBUG}title{$ENDIF});
  //
  f_event := unaEvent.create(false, true);
end;

// --  --
destructor unaOutProcessGate.Destroy();
begin
  inherited;
  //
  leave();
  freeAndNil(f_event);
end;

// --  --
function unaOutProcessGate.gateEnter(timeout: unsigned{$IFDEF DEBUG }; const masterName: string{$ENDIF DEBUG }): bool;
begin
  result := f_event.waitFor(timeout);
  //
  if (result) then begin
    //
    inherited gateEnter(timeout {$IFDEF DEBUG}, masterName{$ENDIF DEBUG });
    //
    f_masterThread := GetCurrentThread();
    f_inside := true;
    f_isBusy := true;
  end;
end;

// --  --
procedure unaOutProcessGate.gateLeave();
begin
  f_masterThread := 0;
  f_inside := false;
  f_event.setState();
  //
  inherited gateLeave();
end;


{ unaInProcessGate }

// --  --
function unaInProcessGate.gateEnter(timeout: unsigned{$IFDEF DEBUG }; const masterName: string{$ENDIF DEBUG }): bool;
var
  tm: int64;
  ct: DWORD;
  tout: bool;
begin
  inherited gateEnter(timeout{$IFDEF DEBUG }, masterName{$ENDIF DEBUG });
  //
  ct := GetCurrentThreadId();
  if (0 < f_rlc) then begin
    //
    result := (ct = f_threadID);
    if (result) then
      inc(f_rlc)
    else begin
      //
      tout := false;
      if (1 < timeout) then begin
	//
	tm := 0;
	repeat
	  //
	  if (0 = tm) then
	    tm := timeMark();
	  //
	  sleep(1);
	  //
	  if (timeout < timeElapsed64(tm)) then begin
	    //
	    tout := true;
	    break;
	  end;
	  //
	until (1 > f_rlc);
	//
	if ((1 > f_rlc) and not tout) then
	  result := gateEnter(max(0, int64(timeout) - timeElapsed64(tm)));
      end;
    end;
  end
  else begin
    //
    result := acquire32Try(f_obj, int(timeout));
    if (result) then begin
      //
      f_threadID := ct;
      if (0 < f_rlc) then begin
	//
	{$IFDEF LOG_UNACLASSES_ERRORS }
	logMessage(className + '.gateEnter() - locking already locked gate');
	{$ENDIF LOG_UNACLASSES_ERRORS }
      end;
      //
      f_rlc := 1;
    end
    else begin
      //
      if (ct = f_threadID) then
	inc(f_rlc);
    end;
  end;
  //
  if (0 < f_rlc) and (0 = f_threadID) then
    f_threadID := 0;
end;

// --  --
procedure unaInProcessGate.gateLeave();
begin
  if (0 < f_rlc) then begin
    //
    if (GetCurrentThreadId() <> f_threadID) then begin
      //
      {$IFDEF LOG_UNACLASSES_ERRORS }
      logMessage(className + '.gateLeave() - leaving from non-owning thread');
      {$ENDIF LOG_UNACLASSES_ERRORS }
    end
    else begin
      //
      if (1 = f_rlc) then begin
	//
	f_threadID := 0;
	f_rlc := 0;
	release32(f_obj);
      end
      else
	dec(f_rlc);
    end;
  end
  else begin
    {$IFDEF LOG_UNACLASSES_ERRORS }
    logMessage(className + '.gateLeave() - leaving non-locked gate');
    {$ENDIF LOG_UNACLASSES_ERRORS }
  end;
end;


{ unaList }

{$IFDEF UNA_PROFILE }

var
  profId_unaClasses_unaList_doAdd: unsigned;
  profId_unaClasses_unaList_doInsert: unsigned;
  profId_unaClasses_unaList_doInsert_move: unsigned;
  profId_unaClasses_unaList_doSetItem: unsigned;
  profId_unaClasses_unaList_locate: unsigned;
  profId_unaClasses_unaList_doSetCapacity: unsigned;
  profId_unaClasses_unaList_compare: unsigned;

{$ENDIF UNA_PROFILE }

// --  --
function unaList.add(item: int32): int;
var
  v: int64;
begin
  if (uldt_int64 = dataType) then begin
    //
    v := item;
    result := doAdd(@v);
  end
  else
    result := add(pointer(item))
end;

// --  --
function unaList.add(item: int64): int;
begin
  if (uldt_int64 <> dataType) then
    result := add(pointer(item))
  else
    result := doAdd(@item);
end;

// --  --
function unaList.add(item: pointer): int;
begin
  result := doAdd(item);
end;

// --  --
function unaList.assign(list: unaList): int;
begin
  result := 0;
  //
  if (nil <> list) then begin
    //
    if (list.lock()) then begin
      try
	result := list.count;
	if (lock()) then begin
	  //
	  try
	    setCapacity(result);
	    if (0 < result) then
	      move(list.listPtr^, listPtr^, result * dataItemSize);
	    //
	    f_count := list.count;
	    //
	    if (0 < f_count) then
	      f_dataEvent.setState();
	    //
	  finally
	    unlock();
	  end;
	end;
      finally
	list.unlock();
      end;
    end;
  end
end;

// --  --
function unaList.asString(const delimiter: string; treatAsSigned: bool; base: unsigned): string;
var
  i: int;
  value: int64;
begin
  result := '';
  //
  if (lockNonEmptyList(self)) then begin
    //
    try
      for i := 0 to count - 1 do begin
	//
	if (treatAsSigned) then begin
	  //
	  case (dataType) of

	    uldt_int32: value := int32(get(i));
	    uldt_int64: value := pInt64(get(i))^;
	    else
	      value := int(get(i));
	  end;
	end
	else begin
	  //
	  case (dataType) of

	    uldt_int32: value := uint32(get(i));
	    uldt_int64: value := pInt64(get(i))^;
	    else
	      value := unsigned(get(i));
	  end;
	end;
	//
	result := result + int2str(value, base);
	//
	if (i < count - 1) then
	  result := result + delimiter;
	//
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
procedure unaList.BeforeDestruction();
begin
  clear(2, true);
  //
  inherited;
  //
  freeAndNil(f_dataEvent);
  freeAndNil(f_gate);
end;

// --  --
function unaList.checkDataEvent(): bool;
begin
  result := (0 < f_count);
  f_dataEvent.setState(result);
end;

// --  --
procedure unaList.clear(doFree: unsigned; force: bool);
begin
  if (lock()) then begin
    try
      while (0 < f_count) do begin
	//
	notifyBeforeRemove(f_count - 1);
	releaseItem(f_count - 1, doFree);
	dec(f_count);
      end;
      //
      doSetCapacity(0, force);
      //
      f_dataEvent.setState(false);
    finally
      unlock();
    end;
  end;
end;

// --  --
function compareItems(list: unaList; a, b: pointer): int; {$IFDEF UNA_OK_INLINE }inline;{$ENDIF UNA_OK_INLINE }
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_compare);
{$ENDIF UNA_PROFILE }
  //
  if (list is unaIDList) then begin
    //
    if (unaIDList(list).getId(a) > unaIDList(list).getId(b)) then
      result := 1
    else
      if (unaIDList(list).getId(a) = unaIDList(list).getId(b)) then
	result := 0
      else
	result := -1;
  end
  else begin
    //
    case (list.dataType) of

      uldt_int32: begin
	//
	if (UIntPtr(a) > UIntPtr(b)) then
	  result := 1
	else
	  if (UIntPtr(a) = UIntPtr(b)) then
	    result := 0
	  else
	    result := -1;
      end;

      uldt_int64: begin
	//
	if ((nil <> a) and (nil <> b)) then begin
	  //
	  if (pInt64(a)^ > pInt64(b)^) then
	    result := 1
	  else
	    if (pInt64(a)^ = pInt64(b)^) then
	      result := 0
	    else
	      result := -1;
	end
	else
	  result := 0;
      end;

      uldt_obj,
      uldt_record,
      uldt_ptr: begin
	//
	if (UIntPtr(a) > UIntPtr(b)) then
	  result := 1
	else
	  if (UIntPtr(a) = UIntPtr(b)) then
	    result := 0
	  else
	    result := -1;
      end;

      uldt_string: begin
	//
	result := list.compareStr(a, b);
      end;

      else
	result := 0;

    end;
  end;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_compare);
{$ENDIF UNA_PROFILE }
end;

// --  --
function unaList.compare(a, b: pointer): int;
begin
  result := compareItems(self, a, b);
end;

// --  --
function unaList.compareStr(a, b: pointer): int;

  // --  --
  function toString(v: punaListStringItem): string;
  var
    sz: uint32;
  begin
    sz := v.r_size;
    setLength(result, sz div sizeOf(result[1]));
    if (0 < sz) then
      move(v.r_data, result[1], sz);
  end;

begin
  if ((nil <> a) and (nil <> b)) then begin
    //
    {$IFDEF __SYSUTILS_H_ }
    result := {$IFDEF FPC }unaUtils.compareStr(toString(a), toString(b))
                   {$ELSE }
                           SysUtils.compareStr(toString(a), toString(b))
              {$ENDIF FPC };
    {$ELSE }
    result := unaUtils.compareStr(toString(a), toString(b));
    {$ENDIF __SYSUTILS_H_ }
  end
  else
    result := 0;
end;

// --  --
function unaList.copyFrom(list: pointer; listSize: int; copyOperation: unaListCopyOpEnum; startIndex: int): int;
begin
  result := doCopyFrom(list, listSize, copyOperation, startIndex);
end;

// --  --
function unaList.copyFrom(list: unaList; copyOperation: unaListCopyOpEnum; startIndex: int): int;
begin
  if (nil <> list) then
    result := doCopyFrom(list.listPtr, list.count * list.dataItemSize, copyOperation, startIndex)
  else
    result := 0;
end;

// --  --
function unaList.copyTo(out list: pointer; includeZeroIndexCount: bool): int;
var
  itemCount: int;
  firstIndex: int;
begin
  if (lock()) then begin
    try
      itemCount := self.count;
      firstIndex := 0;
      //
      if (includeZeroIndexCount) then begin
	//
	inc(itemCount);
	firstIndex := 1;
      end;
      //
      result := itemCount * dataItemSize;
      list := malloc(result, true);
      //
      if (includeZeroIndexCount) then
	move(count, list^, sizeOf(count));
      //
      if (0 < itemCount) then
	move(listPtr^, pArray(list)[firstIndex * dataItemSize], count * dataItemSize);
      //
    finally
      unlock();
    end;
  end
  else
    result := -1;
end;

// --  --
constructor unaList.create(dataType: unaListDataType; sorted: bool);
begin
  inherited create();
  //
  f_gate := unaInProcessGate.create({$IFDEF DEBUG }self._classID + '.f_gate'{$ENDIF DEBUG });
  //
  f_timeout := 1000;
  //
  f_sorted := sorted;
  f_list.r_dt := dataType;
  case (dataType) of

    uldt_int32: f_dataItemSize := 4;
    uldt_int64: f_dataItemSize := 8;
    uldt_ptr,
    uldt_string,
    uldt_record,
    uldt_obj:   f_dataItemSize := sizeOf(pointer);

    else
      f_dataItemSize := sizeOf(pointer);	// general case

  end;
  f_autoFree := (uldt_obj = dataType);
  //
  f_dataEvent := unaEvent.create();
end;

// --  --
function unaList.doAdd(item: pointer): int;
var
  L, H, I, C: int;
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_doAdd);
{$ENDIF UNA_PROFILE }
  //
  if (singleThreaded or lock()) then begin
    //
    try
      if (sorted) then begin
	//
	if (0 < count) then begin
	  //
	  L := 0;
	  H := count - 1;
	  while (L <= H) do begin
	    //
	    I := (L + H) shr 1;
	    C := compareItems(self, get(I), item);
	    if (C < 0) then
	      L := I + 1
	    else begin
	      //
	      if (0 = C) then begin
		//
		L := I;
		break;
	      end
	      else
		H := I - 1;
	    end;
	  end;
	  //
	  result := L;
	end
	else
	  result := count;
      end
      else
	result := count;
      //
      doInsert(result, item, false);
    finally
      if (not singleThreaded) then
	unlock();
    end;
  end
  else
    result := -1;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_doAdd);
{$ENDIF UNA_PROFILE }
end;

// --  --
function unaList.doCopyFrom(list: pointer; listSize: int; copyOperation: unaListCopyOpEnum; startIndex: int): int;
var
  resultCount: int;
  listP: pointer;
  moveSize: int;
  moveCount: int64;
begin
  result := 0;
  //
  if (0 <= listSize) then begin
    //
    listP := list;
    moveCount := listSize div dataItemSize;
  end
  else begin
    //
    case (dataType) of

      uldt_int32: begin
	//
	listP := @pInt32Array(list)[1];
	moveCount := pInt32Array(list)[0];
      end;

      uldt_int64: begin
	//
	listP := @pInt64Array(list)[1];
	moveCount := pInt64Array(list)[0];
      end;

      else begin
	//
	listP := @pPtrArray(list)[1];
	moveCount := UIntPtr(pPtrArray(list)[0]);
      end;

    end;
  end;
  //
  if (0 > moveCount) then
    moveCount := 0;
  //
  moveSize := moveCount * dataItemSize;
  //
  if ((nil <> listP) and (0 < moveSize)) then begin
    //
    startIndex := min(startIndex, count);
    //
    case (copyOperation) of

      unaco_add,
      unaco_insert:
	resultCount := count + moveCount;

      unaco_replaceExisting:
	resultCount := max(count, startIndex + moveCount);

      unaco_assign: begin
	//
	resultCount := moveCount;
	f_count := 0;
      end;

      else
	resultCount := count;
    end;

    //
    if (lock()) then begin
      try
	//
	// allocate necessary space for list items
	doSetCapacity(resultCount);
	//
	case (copyOperation) of

	  unaco_assign,
	  unaco_add:
	    move(listP^, listPtrAt[count]^, moveSize);

	  unaco_insert: begin
	    //
	    if (startIndex < count) then
	      move(listPtrAt[startIndex]^, listPtrAt[startIndex + moveCount]^, (count - startIndex - 1) * dataItemSize);
	    //
	    move(listP^, listPtrAt[startIndex]^, moveSize);
	  end;

	  unaco_replaceExisting:
	    move(listP^, listPtrAt[startIndex]^, moveSize);

	end;
	//
      finally
	unlock();
      end;
    end;
    //
    f_count := resultCount;
    //
    if (0 < f_count) then
      f_dataEvent.setState();
  end;
end;

// -- --
function unaList.doInsert(index: int; item: pointer; brokeSorted: bool): int;
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_doInsert);
{$ENDIF UNA_PROFILE }
  //
  if (singleThreaded or lock()) then begin
    try
      {$IFDEF LOG_UNACLASSES_ERRORS }
      if (index > count) then
	logMessage(self._classID + '.insert(' + int2str(index) + ') - index is out of range, count=' + int2str(count));
      {$ENDIF LOG_UNACLASSES_ERRORS }
      //
      if (index <= count) then begin
	//
	inc(f_count);
	doSetCapacity(f_count);
	//
{$IFDEF UNA_PROFILE }
        profileMarkEnter(profId_unaClasses_unaList_doInsert_move);
{$ENDIF UNA_PROFILE }
	if (index < count - 1) then begin
	  //
	  move(listPtrAt[index]^, listPtrAt[index + 1]^, (count - index - 1) * dataItemSize);
	  //
	  fillChar(listPtrAt[index]^, dataItemSize, #0);	// make sure we will not try to release that item in setItem()
	end;
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_doInsert_move);
{$ENDIF UNA_PROFILE }
	//
	doSetItem(index, item, brokeSorted);
	result := index;
	//
	f_dataEvent.setState();
      end
      else
	result := -1;
      //
    finally
      if (not singleThreaded) then
	unlock();
    end;
  end
  else
    result := -2;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_doInsert);
{$ENDIF UNA_PROFILE }
end;

// --  --
procedure unaList.doReverse();
var
  i: int;
  v64: int64;
  v: pointer;
begin
  if ((1 < count) and lock()) then try
    //
    if (uldt_int32 = dataType) then begin
      //
      asm
	  push	esi
	  push	edi
	  //
	  mov	eax, self
        {$IFDEF FPC }
	  mov	edi, [{$IFDEF CPU64}rax + offset f_list.r_32{$ELSE }eax + offset f_list.r_32{$ENDIF CPU64}]
	{$ELSE }
	  mov	edi, [eax + offset f_list.r_32]
        {$ENDIF FPC }
	  //
	  mov	esi, edi
        {$IFDEF FPC }
	  mov	ecx, [{$IFDEF CPU64}rax + offset f_count{$ELSE }eax + offset f_count{$ENDIF CPU64 }]
	{$ELSE }
	  mov	ecx, [eax + offset f_count]
        {$ENDIF FPC }
	  shl	ecx, 2
	  add	esi, ecx
	  //
	  shr	ecx, 3
    @loop:
	  sub	esi, 4
	  //
        {$IFDEF FPC }
	  mov	eax, [{$IFDEF CPU64}rdi{$ELSE }edi{$ENDIF CPU64}]
	  xchg	eax, [{$IFDEF CPU64}rsi{$ELSE }esi{$ENDIF CPU64}]	//  temp := [esi]; [esi] := eax; eax := temp;
	{$ELSE }
	  mov	eax, [edi]
	  xchg	eax, [esi]	//  temp := [esi]; [esi] := eax; eax := temp;
        {$ENDIF FPC }
	  stosd			// [edi] := eax
				//   edi := edi + 4
	  //
	  loop	@loop
	  //
	  pop	edi
	  pop	esi
      end;
    end
    else begin
      //
      for i := 0 to count shr 1 do begin
	//
	case (dataType) of

	  uldt_int64: begin
	    //
	    v64 := f_list.r_64[i];
	    f_list.r_64[i] := f_list.r_64[count - 1 - i];
	    f_list.r_64[count - 1 - i] := v64;
	  end;

	  else begin
	    //
	    v := f_list.r_ptr[i];
	    f_list.r_ptr[i] := f_list.r_ptr[count - 1 - i];
	    f_list.r_ptr[count - 1 - i] := v;
	  end;

	end;
      end;
    end;
    //
  finally
    unlock();
  end;
end;

// --  --
procedure unaList.doSetCapacity(value: unsigned; force: bool);
var
  ok: bool;
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_doSetCapacity);
{$ENDIF UNA_PROFILE }
  //
  // doSetCapacity() is always called in lock() state
  //
  value := (value + $FF) and $FFFFFF00;	// round to $100 boundary
  //
  if (force or (f_capacity <> value)) then begin
    //
    if (0 = value) then
      ok := force or (f_capacity > 4096{sanity check})
    else
      ok := true;
    //
    if (ok) then
      mrealloc(f_list.r_32, int(value) * dataItemSize);	// all r_XX lists share same memory
							// so we reallocate r_32 here, which takes effect on all other pointers as well

    //
    if (f_capacity < value) then
      fillChar(listPtrAt[f_capacity]^, int(value - f_capacity) * dataItemSize, #0);
    //
    f_capacity := value;
  end;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_doSetCapacity);
{$ENDIF UNA_PROFILE }
end;

// -- --
procedure unaList.doSetItem(index: int; item: pointer; brokeSorted: bool; doFree: unsigned);
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_doSetItem);
{$ENDIF UNA_PROFILE }
  //
  if (lockNonEmptyList(self)) then begin
    try
      {$IFDEF LOG_UNACLASSES_ERRORS }
      if (index >= f_count) then
	logMessage(self._classID + '.setItem2(' + int2str(index) + ') - index is out range, count=' + int2str(count));
      {$ENDIF LOG_UNACLASSES_ERRORS }
      //
      if (index < f_count) then begin
	//
	releaseItem(index, doFree);
	//
	case (dataType) of

	  uldt_int32:
	    f_list.r_32[index] := int32(item);

	  uldt_int64:
	    f_list.r_64[index] := pInt64(item)^;

	  else
	    f_list.r_ptr[index] := item;

	end;
      end;
      //
      if (brokeSorted) then
	f_sorted := false;
      //
    finally
      unlock();
    end;
  end;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_doSetItem);
{$ENDIF UNA_PROFILE }
end;

// --  --
function unaList.get(index: int): pointer;
begin
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if (index >= f_count) then
    logMessage(self._classID + '.get(' + int2str(index) + ') - index is out of count.');
  {$ENDIF LOG_UNACLASSES_ERRORS }
  //
  if ((0 <= index) and (index < count)) then begin
    //
    case (dataType) of
      //
      uldt_int32: result := pointer(f_list.r_32[index]);
      uldt_int64: result := @f_list.r_64[index];
      else
	result := f_list.r_ptr[index]
    end;
  end
  else
    result := nil;
end;

// -- --
function unaList.getDT(): unaListDataType;
begin
  result := f_list.r_dt;
end;

// -- --
function unaList.getListPtr(): pointer;
begin
  result := listPtrAt[0];
end;

// -- --
function unaList.getListPtrAt(index: int): pointer;
begin
  case (dataType) of

    uldt_int32: result := @f_list.r_32[index];
    uldt_int64: result := @f_list.r_64[index];
    else
		result := @f_list.r_ptr[index];
  end;
end;

// -- --
function unaList.getObject(index: int): tObject;
begin
  result := get(index);
end;

// --  --
function unaList.indexOf(item: int32): int;
var
  v: int64;
begin
  if (uldt_int64 = dataType) then begin
    //
    v := item;
    result := indexOf(@v);
  end
  else
    result := indexof(pointer(item));
end;

// --  --
function unaList.indexOf(item: int64): int;
begin
  if (uldt_int64 <> dataType) then
    result := indexOf(pointer(item))
  else
    result := indexOf(@item);
end;

// -- --
function unaList.indexOf(item: pointer): int;
var
  p: pointer;
  L, H, I, C: Integer;
begin
{$IFDEF UNA_PROFILE }
  profileMarkEnter(profId_unaClasses_unaList_locate);
{$ENDIF UNA_PROFILE }
  //
  if (lockNonEmptyList(self)) then begin
    try
      result := -1;
      //
      if (sorted) then begin
	//
	L := 0;
	H := count - 1;
	while (L <= H) do begin
	  //
	  I := (L + H) shr 1;
	  C := compareItems(self, get(I), item);
	  if (0 > C) then
	    L := I + 1
	  else begin
	    //
	    if (0 = C) then begin
	      //
	      result := I;
	      break;
	    end
	    else
	      H := I - 1;
	  end;
	end;
      end
      else begin
	//
	case (dataType) of

	  uldt_int64: begin
	    //
	    p := mscanq(listPtr, count, pInt64(item)^);
	    if (nil <> p) then
	      result := (UIntPtr(p) - UIntPtr(listPtr)) shr 4;
	    //
	  end;

	  else begin
	    //
	    p := mscand(listPtr, count, unsigned(item));
	    if (nil <> p) then
	      result := (UIntPtr(p) - UIntPtr(listPtr)) shr 2;
	    //
	  end;
	end;
      end;
      //
    finally
      unlock();
    end;
  end
  else
    result := -1;
  //
{$IFDEF UNA_PROFILE }
  profileMarkLeave(profId_unaClasses_unaList_locate);
{$ENDIF UNA_PROFILE }
end;

// -- --
function unaList.insert(index: int; item: int32): int;
var
  v: int64;
begin
  if (uldt_int64 = dataType) then begin
    //
    v := item;
    result := doInsert(index, @v);
  end
  else
    result := doInsert(index, pointer(item));
end;

// -- --
function unaList.insert(index: int; item: int64): int;
begin
  if (uldt_int64 <> dataType) then
    result := doInsert(index, pointer(item))
  else
    result := doInsert(index, @item);
end;

// -- --
function unaList.insert(index: int; item: pointer): int;
begin
  result := doInsert(index, item);
end;

// --  --
procedure unaList.internalSetItem(index: int; value: pointer);
begin
  // need this proxy because of default doFree parameter
  setItem(index, value);
end;

// --  --
function unaList.isEmpty(): bool;
begin
  result := (1 > count);
end;

// -- --
function unaList.lock(timeout: unsigned): bool;
begin
  if (f_destroyed) then
    result := false
  else begin
    //
    if (not singleThreaded) then begin
      //
      if (INFINITE = timeout) then
	result := f_gate.enter(self.timeout {$IFDEF DEBUG }, self._classID{$ENDIF DEBUG })
      else
	result := f_gate.enter(timeout {$IFDEF DEBUG}, self._classID{$ENDIF})
    end
    else
      result := true;
  end;
end;

{$IFDEF DEBUG }

// --  --
function unaList.lockedByMe(): int;
begin
  if (f_gate.f_threadID = GetCurrentThreadId()) then
    result := f_gate.f_obj
  else
    result := 0;
end;

{$ENDIF DEBUG }

// --  --
function unaList.mapDoFree(doFree: unsigned): bool;
begin
  case (doFree) of

    0: result := false;
    1: result := true;
    2: result := f_autoFree;

    else
       result := false;
  end;
end;

// --  --
procedure unaList.notifyBeforeRemove(index: int);
begin
  if (assigned(f_onItemBeforeRemove)) then
    f_onItemBeforeRemove(index);
end;

// --  --
procedure unaList.quickSort(L, R: int);
var
  I, J, P: int;
  v32: int32;
  v64: int64;
  vP: pointer;
begin
  repeat
    //
    I := L;
    J := R;
    P := (L + R) shr 1;
    repeat
      //
      while ((I < count) and (0 > compareItems(self, get(I), get(P)))) do
	inc(I);
      //
      while ((J >= 0) and (0 < compareItems(self, get(J), get(P)))) do
	dec(J);
      //
      if (I <= J) then begin
	//
	//ExchangeItems(I, J);
	//
	case (dataType) of

	  uldt_int32: begin
	    //
	    v32 := list.r_32[I];
	    list.r_32[I] := list.r_32[J];
	    list.r_32[J] := v32;
	  end;

	  uldt_int64: begin
	    //
	    v64 := list.r_64[I];
	    list.r_64[I] := list.r_64[J];
	    list.r_64[J] := v64;
	  end;

	  uldt_ptr,
	  uldt_record,
	  uldt_obj,
	  uldt_string: begin
	    //
	    vP := list.r_ptr[I];
	    list.r_ptr[I] := list.r_ptr[J];
	    list.r_ptr[J] := vP;
	  end;

	end;
	//
	if (self is unaIDList) then begin
	  //
	  v64 := unaIDList(self).f_idList64[I];;
	  unaIDList(self).f_idList64[I] := unaIDList(self).f_idList64[J];
	  unaIDList(self).f_idList64[J] := v64;
	end;
	//
	if (P = I) then
	  P := J
	else
	  if (P = J) then
	    P := I;
	//
	inc(I);
	dec(J);
      end;
      //
    until (I > J);
    //
    if (L < J) then
      quickSort(L, J);
    //
    L := I;
    //
  until (I >= R);
end;

// --  --
procedure unaList.releaseItem(index: int; doFree: unsigned);
var
  o: pointer;
begin
  // list is locked here
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if (index >= f_count) then
    logMessage(self._classID + '.releaseItem(' + int2str(index) + ') is out of range, count=' + int2str(count));
  {$ENDIF LOG_UNACLASSES_ERRORS }
  //
  if (index < f_count) then begin
    //
    if (assigned(f_onItemRelease)) then
      f_onItemRelease(index, doFree);
    //
    if (uldt_obj = dataType) then begin
      //
      o := get(index);
      if ((nil <> o) and mapDoFree(doFree)) then
	try
	  tObject(o).free();
	except
	end;
      //
      // this is required because capacity does not follow the count
      fillChar(listPtrAt[index]^, dataItemSize, #0);
    end;
  end;
end;

// --  --
function unaList.removeByIndex(index: int; doFree: unsigned): bool;
begin
  result := false;
  if (lockNonEmptyList(self)) then begin
    try
      {$IFDEF LOG_UNACLASSES_ERRORS }
      if (index >= f_count) then
	logMessage(self._classID + '.remove(' + int2str(index) + ') - index is out of range, count=' + int2str(index));
      {$ENDIF LOG_UNACLASSES_ERRORS }
      //
      if (index < f_count) then begin
	//
	notifyBeforeRemove(index);
	try
	  releaseItem(index, doFree);
	except
	end;
	//
	if (index < count - 1) then
	  move(listPtrAt[index + 1]^, listPtrAt[index]^, (count - index - 1) * dataItemSize);
	//
	// this is required since capacity does not follow the count
	fillChar(listPtrAt[count - 1]^, dataItemSize, #0);
	//
	dec(f_count);
	doSetCapacity(f_count);
	result := true;
	//
	if (1 > f_count) then
	  f_dataEvent.setState(false);
	//
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaList.removeFromEdge(removeFromBegining: bool): bool;
begin
  result := false;
  //
  if (lockNonEmptyList(self)) then begin
    //
    try
      //
      if (removeFromBegining) then
	removeByIndex(0)
      else
	removeByIndex(count - 1);
      //
      result := true;
    finally
      unlock();
    end;
  end;
end;

// -- --
function unaList.removeItem(item: int32): bool;
var
  v: int64;
begin
  if (uldt_int64 = dataType) then begin
    //
    v := item;
    result := removeItem(@v);
  end
  else
    result := removeItem(pointer(item));
end;

// --  --
function unaList.removeItem(item: int64): bool;
begin
  if (uldt_int64 <> dataType) then
    result := removeItem(pointer(item))
  else
    result := removeItem(@item);
end;

// --  --
function unaList.removeItem(item: pointer; doFree: unsigned): bool;
var
  index: int;
begin
  result := false;
  //
  if (lockNonEmptyList(self)) then
    try
      index := indexOf(item);
      if (0 <= index) then
	result := removeByIndex(index, doFree);
      //
    finally
      unlock();
    end;
end;

// -- --
procedure unaList.reverse();
begin
  doReverse();
end;

// --  --
procedure unaList.setCapacity(value: unsigned);
begin
  if (singleThreaded or lock()) then begin
    try
      // should be called in lock() state
      doSetCapacity(value);
    finally
      if (not singleThreaded) then
	unlock();
    end;
  end;
end;

// --  --
procedure unaList.setItem(index: int; item: int32);
var
  v: int64;
begin
  if (uldt_int64 = dataType) then begin
    //
    v := item;
    setItem(index, @v);
  end
  else
    setItem(index, pointer(item));
end;

// --  --
procedure unaList.setItem(index: int; item: int64);
begin
  if (uldt_int64 <> dataType) then
    setItem(index, pointer(item))
  else
    setItem(index, @item);
end;

// --  --
procedure unaList.setItem(index: int; item: pointer; doFree: unsigned);
begin
  // BCB stub
  doSetItem(index, item, true, doFree);
end;

// --  --
function unaList.setItem(itemToReplace, newItem: pointer; doFree: unsigned): unsigned;
var
  index: int;
begin
  if (singleThreaded or lock()) then begin
    try
      index := indexOf(itemToReplace);
      if (0 <= index) then begin
	//
	setItem(index, newItem, doFree);
	result := index;
      end
      else
	result := add(newItem);
      //
    finally
      if (not singleThreaded) then
	unlock();
    end;
  end
  else
    result := 0;
end;

// --  --
function unaList.sort(): bool;
begin
  if (lockNonEmptyList(self)) then try
    //
    quickSort(0, count - 1);
    //
    f_sorted := true;
  finally
    unlock();
  end
  else
    f_sorted := (1 > count);
  //
  result := sorted;
end;

// --  --
procedure unaList.unlock();
begin
  if (not singleThreaded) then
    f_gate.leave();
end;

// --  --
function unaList.waitForData(timeout: unsigned): bool;
begin
  result := f_dataEvent.waitFor(timeout);
end;


{ unaRecordList }

// --  --
constructor unaRecordList.create(autoFree: bool; sorted: bool);
begin
  inherited create(uldt_ptr, sorted);
  //
  f_autoFree := autoFree;
end;

// --  --
procedure unaRecordList.releaseItem(index: int; doFree: unsigned);
begin
  inherited;
  //
  if (mapDoFree(doFree) and (nil <> get(index))) then
    mrealloc(f_list.r_ptr[index]);
end;


{ unaIdList }

// --  --
procedure unaIdList.AfterConstruction();
begin
  inherited;
  //
  f_idList64 := nil;
  f_idList64Capacity := 0;
end;

// --  --
procedure unaIdList.BeforeDestruction();
begin
  inherited;
  //
  f_idList64Capacity := 0;
  mrealloc(f_idList64);
end;

// --  --
function unaIdList.doAdd(item: pointer): int;
var
  ok: bool;
begin
  if (lock()) then begin
    try
      if (not allowDuplicateId) then
	ok := (0 > indexOfId(getId(item)))
      else
	ok := true;
      //
      if (ok) then
	result := inherited doAdd(item)
      else
	result := -1;
      //
    finally
      unlock();
    end;
  end
  else
    result := 0;
end;

// --  --
function unaIdList.doCopyFrom(list: pointer; listSize: int; copyOperation: unaListCopyOpEnum; startIndex: int): int;
var
  i: unsigned;
begin
  // 1. copy list
  result := inherited doCopyFrom(list, listSize, copyOperation, startIndex);
  //
  // 2. re-create id-list
  //
  // we know that inherited doCopyFrom() had called doSetCapacity() with new count,
  // so ID list must have a proper size allocated
  //
  if (0 < count) then begin
    //
    for i := 0 to count -1 do
      f_idList64[i] := getId(get(i));
  end;
end;

// --  --
procedure unaIdList.doReverse();
var
  i: int;
  a: int64;
begin
  inherited;
  //
  if (lockNonEmptyList(self)) then begin
    try
      if (0 < count) then begin
	//
	for i := 0 to count div 2 do begin
	  //
	  a := f_idList64[i];
	  f_idList64[i] := f_idList64[count - 1 - i];
	  f_idList64[count - 1 - i] := a;
	end;
	//
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
procedure unaIdList.doSetCapacity(value: unsigned; force: bool);
begin
  inherited;
  //
  setIdListCapacity(value, force);
end;

// --  --
function unaIdList.doInsert(index: int; item: pointer; brokeSorted: bool): int;
begin
  if (lock()) then begin
    try
      {$IFDEF LOG_UNACLASSES_ERRORS }
      if (index > count) then
	logMessage(self._classID + '.insert2(' + int2str(index) + ') - index is out of range, count=' + int2str(count));
      {$ENDIF LOG_UNACLASSES_ERRORS }
      //
      // followed inherited insert will call set_item(), so we should not care about valid id here, simply passing the nil
      if (index <= count) then begin
	//
	setIdListCapacity(count + 1);
	if (index < count) then
	  move(f_idList64[index], f_idList64[index + 1], (count - index) * sizeof(f_idList64[0]));
	//
	f_idList64[index] := -1;	// no ID yet, it will be set in the followed setItem() call
	//
	result := inherited doInsert(index, item, brokeSorted);
      end
      else
	result := -2;
      //
    finally
      unlock();
    end;
  end
  else
    result := -1;
end;

// --  --
procedure unaIdList.doSetItem(index: int; item: pointer; brokeSorted: bool; doFree: unsigned);
begin
  if (lock()) then begin
    try
      f_idList64[index] := getId(item);
      //
      inherited;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaIdList.getId(item: pointer): int64;
begin
  result := -1;	// should be overrided
end;

// --  --
function unaIdList.indexOfId(id: int64; startingIndex: int): int;
var
  p: pointer;
  L, H, I, C: Integer;
begin
  result := -1;
  //
  if (lockNonEmptyList(self)) then begin
    try
      //
      if (sorted) then begin
	//
	L := startingIndex;
	H := count - 1;
	while (L <= H) do begin
	  //
	  I := (L + H) shr 1;
	  //
	  //C := compareItems(self, get(I), item);
	  if (f_idList64[i] > id) then
	    C := 1
	  else
	    if (f_idList64[i] = id) then
	      C := 0
	    else
	      C := -1;
	  //
	  if (0 > C) then
	    L := I + 1
	  else begin
	    //
	    if (0 = C) then begin
	      //
	      result := I;
	      break;
	    end
	    else
	      H := I - 1;
	  end;
	end;
      end
      else begin
	//
	if (startingIndex < count) then
	  p := mscanq(@f_idList64[startingIndex], f_count - startingIndex, id)
	else
	  p := nil;
	//
	if (nil <> p) then
	  result := startingIndex + int(UIntPtr(p) - UIntPtr(@f_idList64[startingIndex])) shr 3;
      end;
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaIdList.itemById(id: int64; startingIndex: int; timeout: unsigned): pointer;
begin
  result := get(indexOfId(id, startingIndex))
end;

// --  --
procedure unaIdList.notifyBeforeRemove(index: int);
begin
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if (index >= count) then
    logMessage(self._classID + '.notifyBeforeRemove(' + int2str(index) + ') - index is out of range, count=' + int2str(count));
  {$ENDIF LOG_UNACLASSES_ERRORS }
  //
  if (index < count) then begin
    //
    if (index < count - 1) then
      move(f_idList64[index + 1], f_idList64[index], (count - index - 1) * sizeof(f_idList64[0]));
    //
    // this is required since capacity does not follow the count
    f_idList64[count - 1] := -1;
    setIdListCapacity(f_idList64Capacity - 1);
  end;
  //
  inherited;
end;

// --  --
function unaIdList.removeById(id: int64; doFree: unsigned): bool;
var
  index: int;
begin
  result := false;
  //
  if (lockNonEmptyList(self)) then
    try
      index := indexOfId(id);
      if (0 <= index) then
	result := removeByIndex(index, doFree);
      //
    finally
      unlock();
    end;
end;

// --  --
procedure unaIdList.setIdListCapacity(value: unsigned; force: bool);
var
  ok: bool;
begin
  // doSetCapacity() is always called in lock() state
  //
  value := (value + $FF) and $FFFFFF00;	// round to $100 boundary
  if (force or (f_idList64Capacity <> value)) then begin
    //
    if (0 = value) then
      ok := force or (f_idList64Capacity > 4096{sanity check})
    else
      ok := true;
    //
    if (ok) then
      mrealloc(f_idList64, value * sizeof(f_idList64[0]));
    //
    if (f_idList64Capacity < value) then
      fillChar(f_idList64[f_idList64Capacity], (value - f_idList64Capacity) * sizeof(f_idList64[0]), #254);
    //
    f_idList64Capacity := value;
  end;
end;

// --  --
function unaIdList.updateIds(): unsigned;
var
  i: unsigned;
begin
  if (lockNonEmptyList(self)) then begin
    try
      //
      for i := 0 to count - 1 do
	f_idList64[i] := getId(get(i));
      //
      result := count;
      //
    finally
      unlock();
    end;
  end
  else
    result := 0;
end;


{ unaObjectList }

// -- --
constructor unaObjectList.create(autoFree: bool; sorted: bool);
begin
  inherited create(uldt_obj, sorted);
  //
  f_autoFree := autoFree;
end;


type
  {*
    We need access to protected methods of tInterfacedObject
  }
  tMyInterfacedObject = class(tInterfacedObject)
  end;

{ unaIntfObjectList }

// --  --
function unaIntfObjectList.doAdd(item: pointer): int;
begin
  result := inherited doAdd(item);
  //
  if (-1 <> result) then
    tMyInterfacedObject(item)._AddRef();	// increase ref count
end;

// --  --
function unaIntfObjectList.itemAddRef(index: int): int;
begin
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if (index >= count) then
    logMessage(self._classID + '.itemAddRef(' + int2str(index) + ') - index is out of range, count=' + int2str(count));
  {$ENDIF LOG_UNACLASSES_ERRORS }
  //
  if (index < count) then
    result := tMyInterfacedObject(item[index])._AddRef()	// increase ref count
  else
    result := -1;  
end;

// --  --
procedure unaIntfObjectList.releaseItem(index: int; doFree: unsigned);
begin
  if (mapDoFree(doFree)) then begin
    //
    if (nil <> item[index]) then
      tMyInterfacedObject(item[index])._Release();	// decrease ref count
    //
    doFree := 0;
  end;
  //
  inherited releaseItem(index, doFree);
end;


{ unaStringList }

// --  --
function unaStringList.add(const value: string): int;
begin
  result := inherited add(allocateBuf(value));
end;

// --  --
function unaStringList.allocateBuf(const item: string): punaListStringItem;
var
  sz: uint32;
begin
  sz := length(item) * sizeOf(item[1]);
  result := malloc(sz + sizeOf(result));
  result.r_size := sz;
  //
  if (0 < sz) then
    move(item[1], result.r_data, sz);
end;

// --  --
constructor unaStringList.create();
begin
  inherited create();
  //
  f_list.r_dt := uldt_string;	// small hack
end;

// --  --
function unaStringList.get(index: int): string;
var
  buf: punaListStringItem;
begin
  result := '';
  //
  if (lockNonEmptyList(self)) then begin
    try
      if (index < count) then begin
	//
	buf := inherited get(index);
	if (nil <> buf) then begin
	  //
	  setLength(result, buf.r_size div sizeOf(result[1]));
	  if (0 < buf.r_size) then
	    move(buf.r_data, result[1], buf.r_size);
	end;
      end
      else begin
	//
	{$IFDEF LOG_UNACLASSES_ERRORS }
	logMessage(self._classID + '.get(' + int2str(index) + ') - index is out of range, count=' + int2str(count));
	{$ENDIF LOG_UNACLASSES_ERRORS }
      end;
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.getName(const index: int): string;
var
  p: int;
  v: string;
begin
  result := '';
  //
  if (lock()) then begin
    try
      if (0 <= index) then begin
	//
	v := get(index);
	p := pos('=', v);
	//
	if (0 < p) then
	  result := copy(v, 1, p - 1)
	else
	  result := v;
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.getText(): string;
var
  i: int;
begin
  result := '';
  //
  if (lockNonEmptyList(self)) then begin
    try
      for i := 0 to count - 1 do
	result := result + get(i) + #13#10;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.getValue(const index: string): string;
var
  i: int;
  p: int;
  v: string;
begin
  result := '';
  //
  if (lock()) then begin
    try
      i := indexOfValue(index);
      if (0 <= i) then begin
	//
	v := get(i);
	p := pos('=', v);
	//
	if (0 < p) then
	  result := copy(v, p + 1, maxInt);
	//
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.indexOf(const value: string; exact: bool): int;
var
  i: int;
begin
  result := -1;
  if ((0 < count) and lock()) then begin
    //
    try
      for i := 0 to count - 1 do begin
	//
	if ((exact and (get(i) = value)) or
	    (not exact and sameString(get(i), value))) then begin
	  //
	  result := i;
	  break;
	end;
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.indexOfValue(const name: string): int;
var
  i: int;
  lc: string;
begin
  result := -1;
  //
  if (lockNonEmptyList(self)) then begin
    try
      lc := lowerCase(name) + '=';
      //
      for i := 0 to count - 1 do begin
	//
	if (1 = pos(lc, lowerCase(get(i)))) then begin
	  //
	  result := i;
	  break;
	end;
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaStringList.insert(index: int; const value: string): int;
begin
  result := inherited insert(index, nil);
  //
  f_list.r_ptr[result] := allocateBuf(value);
end;

// --  --
function unaStringList.readFromFile(const fileName: wString): int;
var
  newText: aString;
  sz: int;
  rsz: unsigned;
begin
  sz := fileSize(fileName);
  if (0 <= sz) then begin
    //
    setLength(newText, sz);
    //
    rsz := unsigned(sz);
    if (0 < rsz) then
      result := unaUtils.readFromFile(fileName, @newText[1], rsz)
    else
      result := 0;
    //
    self.text := string(newText);
  end
  else
    result := -1;	// file does not exists, or there was some error
end;

// --  --
procedure unaStringList.setItem(index: int; const item: string);
begin
  inherited setItem(index, allocateBuf(item));
end;

// --  --
procedure unaStringList.setName(const index: int; const v: string);
begin
  if (lock()) then begin
    try
      if (0 <= index) then
	setItem(index, v + '=' + value[v])
      else
	add(v + '=');
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
procedure unaStringList.setText(const value: string);
var
  s: aString;
  p: paChar;
  pStart: paChar;
begin
  if (lock()) then begin
    try
      clear();
      //
      if ('' <> value) then begin
	//
        s := aString(value);
	p := @s[1];
	pStart := p;
	//
	while (p^ <> #0) do begin
	  //
	  if ((p^ in [#13, #10]) or (#0 = p[1])) then begin
	    //
	    add(copy(string(pStart), 1, int(p) - int(pStart)));
	    //
	    inc(p);
	    if ((p <> #0) and (p^ in [#13, #10])) then
	      inc(p);
	    //
	    pStart := p;
	  end
	  else
	    inc(p);
	end;
      end;
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
procedure unaStringList.setValue(const index, value: string);
var
  i: int;
begin
  if (lock()) then begin
    try
      i := indexOfValue(index);
      //
      if (0 <= i) then
	setItem(i, index + '=' + value)
      else
	add(index + '=' + value);
      //
    finally
      unlock();
    end;
  end;
end;


{ unaWideStringList }

// --  --
function unaWideStringList.add(const value: wString): int;
begin
  result := inherited add(allocateBuf(value));
end;

// --  --
function unaWideStringList.allocateBuf(const item: wString): punaListStringItem;
var
  sz: unsigned;
begin
  sz := length(item) * sizeOf(item[1]);
  result := malloc(sz + sizeOf(result));
  result.r_size := sz;
  //
  if (0 < sz) then
    move(item[1], result.r_data, sz);
end;

// --  --
function unaWideStringList.get(index: int): wString;
var
  buf: punaListStringItem;
begin
  result := '';
  //
  if (lockNonEmptyList(self)) then begin
    try
      if (index < count) then begin
	//
	buf := inherited get(index);
	if (nil <> buf) then begin
	  //
	  setLength(result, buf.r_size div sizeOf(result[1]));
	  //
	  if (0 < buf.r_size) then
	    move(buf.r_data, result[1], buf.r_size);
	end;
      end
      else begin
	//
	{$IFDEF LOG_UNACLASSES_ERRORS }
	logMessage(self._classID + '.get(' + int2str(index) + ') - index is out range, count=' + int2str(count));
	{$ENDIF LOG_UNACLASSES_ERRORS }
      end;
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaWideStringList.getText(): wString;
var
  i: int;
begin
  result := '';
  //
  if (lockNonEmptyList(self)) then begin
    try
      for i := 0 to count - 1 do
	result := result + get(i) + #13#10;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaWideStringList.getValue(const index: wString): wString;
var
  i: int;
  p: int;
  v: wString;
begin
  result := '';
  //
  if (lock()) then begin
    try
      i := indexOfValue(index);
      if (0 <= i) then begin
	//
	v := get(i);
	p := pos('=', v);
	//
	if (0 < p) then
	  result := copy(v, p + 1, maxInt);
	//
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaWideStringList.indexOf(const value: wString; exact: bool): int;
var
  i: int;
begin
  result := -1;
  if ((0 < count) and lock()) then begin
    //
    try
      for i := 0 to count - 1 do begin
	//
	if ((exact and (get(i) = value)) or
	    (not exact and sameString(get(i), value))) then begin
	  //
	  result := i;
	  break;
	end;
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaWideStringList.indexOfValue(const name: wString): int;
var
  i: int;
  lc: wString;
begin
  result := -1;
  //
  if (lockNonEmptyList(self)) then begin
    try
      lc := lowerCase(name) + '=';
      //
      for i := 0 to count - 1 do begin
	//
	if (1 = pos(lc, lowerCase(get(i)))) then begin
	  //
	  result := i;
	  break;
	end;
      end;
    finally
      unlock();
    end;
  end;
end;

// --  --
function unaWideStringList.readFromFile(const fileName: wString): int;
var
  newText: wString;
  sz: int;
  rsz: unsigned;
begin
  sz := fileSize(fileName);
  if (0 <= sz) then begin
    //
    setLength(newText, sz);
    //
    rsz := unsigned(sz);
    if (0 < rsz) then
      result := unaUtils.readFromFile(fileName, @newText[1], rsz)
    else
      result := 0;
    //
    text := newText;
  end
  else
    result := -1;	// file does not exists, or there was some error
end;

// --  --
procedure unaWideStringList.setItem(index: int; const item: wString);
begin
  inherited setItem(index, allocateBuf(item));
end;

// --  --
procedure unaWideStringList.setText(const value: wString);
var
  p: pwChar;
  pStart: pwChar;
begin
  if (lock()) then begin
    try
      clear();
      //
      if ('' <> value) then begin
	//
	p := @value[1];
	pStart := p;
	//
	while (p^ <> #0) do begin
	  //
	  if ((aChar(p^) in [#13, #10]) or (#0 = p[1])) then begin
	    //
	    add(copy(pStart, 1, int(p) - int(pStart)));
	    //
	    inc(p);
	    if ((p^ <> #0) and (aChar(p^) in [#13, #10])) then
	      inc(p);
	    //
	    pStart := p;
	  end
	  else
	    inc(p);
	end;
      end;
      //
    finally
      unlock();
    end;
  end;
end;

// --  --
procedure unaWideStringList.setValue(const index, value: wString);
var
  i: int;
begin
  if (lock()) then begin
    try
      i := indexOfValue(index);
      //
      if (0 <= i) then
	setItem(i, index + '=' + value)
      else
	add(index + '=' + value);
      //
    finally
      unlock();
    end;
  end;
end;


{ unaFileList }

// --  --
procedure unaFileList.addRecord(data: WIN32_FIND_DATAW);
begin
  add(malloc(sizeOf(data), @data));
end;

{$IFNDEF NO_ANSI_SUPPORT }

// --  --
procedure unaFileList.addRecord(data: WIN32_FIND_DATAA);
begin
  add(malloc(sizeOf(data), @data));
end;

{$ENDIF NO_ANSI_SUPPORT }

// --  --
procedure unaFileList.AfterConstruction();
begin
  inherited;
  //
  f_path := unaStringList.create();
  f_subPath := unaStringList.create();
  //
  refresh(f_root, f_mask, f_includeSubF);
end;

// --  --
procedure unaFileList.BeforeDestruction();
begin
  inherited;
  //
  freeAndNil(f_path);
  freeAndNil(f_subPath);
end;

// --  --
constructor unaFileList.create(const path, mask: wString; includeSubF: bool);
begin
  f_root := path;
  f_mask := mask;
  f_includeSubF := includeSubF;
  //
  inherited create();
end;

// --  --
function unaFileList.getAttributes(index: int): unsigned;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := WIN32_FIND_DATAW(get(index)^).dwFileAttributes
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := WIN32_FIND_DATAA(get(index)^).dwFileAttributes;
{$ENDIF NO_ANSI_SUPPORT }
  ;
end;

// --  --
function unaFileList.getFileDate(index, dateIndex: int): SYSTEMTIME;
var
  ft: FILETIME;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
    //
    with (WIN32_FIND_DATAW(get(index)^)) do
      //
      case (dateIndex) of

	0: ft := ftCreationTime; 	// creation
	1: ft := ftLastAccessTime; 	// last access
	2: ft := ftLastWriteTime;	// last write

	else
	   fillChar(ft, sizeOf(ft), #0);

      end;
    //
{$IFNDEF NO_ANSI_SUPPORT }
  end
  else begin
    //
    with (WIN32_FIND_DATAA(get(index)^)) do begin
      //
      case (dateIndex) of

	0: ft := ftCreationTime;	// creation
	1: ft := ftLastAccessTime;	// last access
	2: ft := ftLastWriteTime;	// last write

	else
	  fillChar(ft, sizeOf(ft), #0);

      end;
    end;
  end;
{$ENDIF NO_ANSI_SUPPORT }
  //
  FileTimeToSystemTime(ft, result);
end;

// --  --
function unaFileList.getFileName(index: int): wString;
begin
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if ((index < 0) or (index >= count)) then
    logMessage(self._classID + '.getFileName(' + int2str(index) + ') - index is out range, count=' + int2str(count));
  {$ENDIF LOG_UNACLASSES_ERRORS }
  //
  if ((index >= 0) and (index < count)) then begin
    //
{$IFNDEF NO_ANSI_SUPPORT }
    if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
      result := WIN32_FIND_DATAW(get(index)^).cFileName
{$IFNDEF NO_ANSI_SUPPORT }
    else
      result := wString(WIN32_FIND_DATAA(get(index)^).cFileName);
{$ENDIF NO_ANSI_SUPPORT }
    ;
  end
  else
    result := '';
end;

// --  --
function unaFileList.getFileSize(index: int): int64;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := (int64(WIN32_FIND_DATAW(get(index)^).nFileSizeHigh) shl 32) + int64(WIN32_FIND_DATAW(get(index)^).nFileSizeLow)
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := (int64(WIN32_FIND_DATAA(get(index)^).nFileSizeHigh) shl 32) + int64(WIN32_FIND_DATAA(get(index)^).nFileSizeLow);
{$ENDIF NO_ANSI_SUPPORT }
  ;
end;

// --  --
function unaFileList.getPath(index: int): wString;
begin
  result := UTF82UTF16(aString(f_path.get(index)));
end;

// --  --
function unaFileList.getSubLevel(index: int): unsigned;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := WIN32_FIND_DATAW(get(index)^).dwReserved1
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := WIN32_FIND_DATAA(get(index)^).dwReserved1;
{$ENDIF NO_ANSI_SUPPORT }
  ;
end;

// --  --
function unaFileList.getSubPath(index: int): wString;
begin
  result := UTF82UTF16(aString(f_subPath.get(index)));
end;

// --  --
function unaFileList.refresh(const path, mask: wString; includeSubF, clearUp: bool; subLevel: int): bool;
var
  res: tHandle;
  arg: wString;
  fdw: WIN32_FIND_DATAW;
{$IFNDEF NO_ANSI_SUPPORT }
  fda: WIN32_FIND_DATAA;
{$ENDIF NO_ANSI_SUPPORT }
  more: bool;
begin
  arg := addBackSlash(path) + mask;
  //
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    res := FindFirstFileW(pwChar(arg), fdw)
{$IFNDEF NO_ANSI_SUPPORT }
  else
    res := FindFirstFileA(paChar(aString(arg)), fda);
{$ENDIF NO_ANSI_SUPPORT }
  ;
  //
  result := false;
  if (INVALID_HANDLE_VALUE <> res) then begin
    //
    try
      if (lock()) then begin
	try
	  if (clearUp) then begin
	    //
	    clear();
	    f_path.clear();
	    f_subPath.clear();
	    f_curDir := addBackSlash(path);
	    //
	    f_root := path;
	    f_mask := mask;
	  end;
	  //
	  more := true;
	  while (more) do begin
	    //
{$IFNDEF NO_ANSI_SUPPORT }
	    if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
	      // WIDE
	      if (includeSubF and (0 <> (FILE_ATTRIBUTE_DIRECTORY and fdw.dwFileAttributes))) then begin
		//
		if (('.' <> wString(fdw.cFileName)) and ('..' <> fdw.cFileName)) then begin
		  //
		  arg := f_curDir;
		  f_curDir := addBackSlash(addBackSlash(path) + fdw.cFileName);
		  try
		    refresh(addBackSlash(path) + fdw.cFileName, mask, true, false, subLevel + 1);
		  finally
		    f_curDir := arg;
		  end;
		end;
	      end;
	      //
	      fdw.dwReserved1 := subLevel;
	      addRecord(fdw);
	      //
{$IFNDEF NO_ANSI_SUPPORT }
	    end
	    else begin
	      // ANSI
	      if (includeSubF and (0 <> (FILE_ATTRIBUTE_DIRECTORY and fda.dwFileAttributes))) then begin
		//
		if (('.' <> aString(fda.cFileName)) and ('..' <> fda.cFileName)) then begin
		  //
		  arg := f_curDir;
		  f_curDir := addBackSlash(addBackSlash(path) + fdw.cFileName);
		  try
		    refresh(addBackSlash(path) + wString(fda.cFileName), mask, true, false, subLevel + 1);
		  finally
		    f_curDir := arg;
		  end;
		end;
	      end;
	      //
	      fda.dwReserved1 := subLevel;
	      addRecord(fda);
	    end;
{$ENDIF NO_ANSI_SUPPORT }
	    //
	    f_path.add(string(UTF162UTF8(f_curDir)));
	    f_subPath.add(string(UTF162UTF8(copy(f_curDir, length(f_root) + 1, maxInt))));
	    //
{$IFNDEF NO_ANSI_SUPPORT }
	    if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	      more := FindNextFileW(res, fdw)
{$IFNDEF NO_ANSI_SUPPORT }
	    else
	      more := FindNextFileA(res, fda);
{$ENDIF NO_ANSI_SUPPORT }
            ;
	    //
	  end;
	  //
	  result := true;
	finally
	  unlock();
	end;
      end;
      //
    finally
      Windows.FindClose(res);
    end;
  end;
end;


{ unaRegistry }

// --  --
procedure unaRegistry.BeforeDestruction();
begin
  inherited;
  //
  close();
end;

// --  --
procedure unaRegistry.close();
begin
  if (0 <> f_key) then begin
    //
    RegCloseKey(f_key);
    f_key := 0;
  end;
end;

// --  --
constructor unaRegistry.create(root: HKEY);
begin
  inherited create();
  //
  f_root := root;
end;

// --  --
function _regQueryValueEx(hKey: HKEY; const valueName: wString; lpType: pDWORD; lpData: pByte; lpcbData: pDWORD): int;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := RegQueryValueExW(hKey, pwChar(valueName), nil, lpType, lpData, lpcbData)
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := RegQueryValueExA(hKey, paChar(aString(valueName)), nil, lpType, lpData, lpcbData);
{$ENDIF NO_ANSI_SUPPORT }
end;

// --  --
function unaRegistry.get(const name: wString; def: int): int;
var
  size: DWORD;
begin
  size := sizeOf(result);
  //
  if (ERROR_SUCCESS <> _regQueryValueEx(f_key, name, nil, pByte(@result), @size)) then
    result := def;
end;

// --  --
function unaRegistry.get(const name: wString; buf: pointer; size: DWORD): unsigned;
begin
  if (ERROR_SUCCESS = _regQueryValueEx(f_key, name, nil, buf, @size)) then
    result := size
  else
    result := 0;
end;

{$IFNDEF CPU64 }

// --  --
function unaRegistry.get(const name: wString; const def: int64): int64;
var
  size: unsigned;
begin
  size := sizeOf(result);
  //
  if (ERROR_SUCCESS <> _regQueryValueEx(f_key, name, nil, pByte(@result), @size)) then
    result := def;
end;

{$ENDIF CPU64 }

// --  --
function unaRegistry.get(const name: wString; const def: aString): aString;
var
  keyType: DWORD;
  size: DWORD;
begin
  size := 0;
  //
  if (ERROR_SUCCESS = _regQueryValueEx(f_key, name, @keyType, nil, @size)) then begin
    if (
	 (keyType = REG_SZ) or
	 (keyType = REG_MULTI_SZ) or
	 (keyType = REG_EXPAND_SZ)
       ) then begin
      //
      setLength(result, size - 1);
      //
      if (ERROR_SUCCESS <> _regQueryValueEx(f_key, name, nil, pByte(@result[1]), @size)) then
	result := def;
    end;
  end;
end;

// --  --
function unaRegistry.get(const name: wString; def: unsigned): unsigned;
var
  size: DWORD;
begin
  size := sizeof(result);
  //
  if (ERROR_SUCCESS <> _regQueryValueEx(f_key, name, nil, pByte(@result), @size)) then
    result := def;
end;

// --  --
function unaRegistry.get(const name: wString; var buf: pointer): DWORD;
begin
  result := 0;
  if (ERROR_SUCCESS = _regQueryValueEx(f_key, name, nil, nil, @result)) then begin
    //
    buf := malloc(result);
    if (ERROR_SUCCESS <> _regQueryValueEx(f_key, name, nil, buf, @result)) then begin
      //
      mrealloc(buf);
      result := 0;
    end;
  end
  else begin
    //
    buf := nil;
    result := 0;
  end;
end;

{$IFDEF __AFTER_D5__ }

// --  --
function unaRegistry.get(const name, def: wString): wString;
begin
  result := wString(get(name, aString(def)));
end;

{$ENDIF __AFTER_D5__ }

// --  --
function unaRegistry.loadKeyNames(list: unaStringList): int;
var
  num: unsigned;
  name: array[0..MAX_PATH] of aChar;
  size: DWORD;
begin
  list.clear();
  num := 0;
  size := MAX_PATH;
  //
  while (ERROR_SUCCESS = RegEnumKeyExA(f_key, num, name, size, nil, nil, nil, nil)) do begin
    //
    list.add(string(name));
    inc(num);
    size := MAX_PATH;
  end;
  //
  result := list.count;
end;

// --  --
function unaRegistry.open(const keyPath: wString; access: unsigned): int;
begin
  close();
  //
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := RegOpenKeyExW(f_root, pwChar(keyPath), 0, access, f_key)
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := RegOpenKeyExA(f_root, paChar(aString(keyPath)), 0, access, f_key);
{$ENDIF NO_ANSI_SUPPORT }
  ;
  //
  {$IFDEF LOG_UNACLASSES_ERRORS }
  if (ERROR_SUCCESS <> result) then
    logMessage(self._classID + '.open() fails.');
  {$ENDIF LOG_UNACLASSES_ERRORS }
end;

// --  --
function _regSetValueEx(hKey: HKEY; const valueName: wString; dwType: DWORD; lpData: pByte; cbData: DWORD; forceAnsi: bool = false): int;
begin
  if (not forceAnsi{$IFNDEF NO_ANSI_SUPPORT } and g_wideApiSupported{$ENDIF NO_ANSI_SUPPORT }) then
    result := RegSetValueExW(hKey, pwChar(valueName), 0, dwType, lpData, cbData)
  else
    result := RegSetValueExA(hKey, paChar(aString(valueName)), 0, dwType, lpData, cbData);
end;

// --  --
function unaRegistry.setValue(const name: wString; value: int): bool;
begin
  result := (ERROR_SUCCESS = _regSetValueEx(f_key, name, REG_DWORD, pByte(@value), sizeOf(value)));
end;

// --  --
function unaRegistry.setValue(const name: wString; buf: pointer; size: unsigned; keyType: int): int;
begin
  result := _regSetValueEx(f_key, name, keyType, buf, size);
end;

const
{$IFDEF __AFTER_D5__ }
  {$EXTERNALSYM REG_QWORD }
{$ENDIF __AFTER_D5__ }
  REG_QWORD = 11;

{$IFNDEF CPU64 }

// --  --
function unaRegistry.setValue(const name: wString; value: int64): bool;
begin
  result := (ERROR_SUCCESS = _regSetValueEx(f_key, name, REG_QWORD, pByte(@value), sizeOf(value)));
end;

{$ENDIF CPU64 }

// --  --
function unaRegistry.setValue(const name: wString; const value: aString): bool;
begin
  result := (ERROR_SUCCESS = _regSetValueEx(f_key, name, REG_SZ, pByte(@value[1]), length(value), true));
end;

// --  --
function unaRegistry.setValue(const name: wString; value: unsigned): bool;
begin
  result := (ERROR_SUCCESS = _regSetValueEx(f_key, name, REG_DWORD, pByte(@value), sizeOf(value)));
end;

{$IFDEF __AFTER_D5__ }

// --  --
function unaRegistry.setValue(const name, value: wString): bool;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (not g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    result := setValue(name, aString(value))
{$IFNDEF NO_ANSI_SUPPORT }
  else
    result := (ERROR_SUCCESS = _regSetValueEx(f_key, name, REG_SZ, pByte(@value[1]), length(value) * sizeOf(value[1])));
{$ENDIF NO_ANSI_SUPPORT }
end;

{$ENDIF __AFTER_D5__ }


// -- threads --

type
  unaThreadRec = record
    //
    r_lockCount: int;
    //
    r_status: unaThreadStatus;
    r_priority: int;
    //
    r_shouldStop: bool;
    r_handle: tHandle;
    r_threadId: DWORD;
    //
    r_eventStop: tHandle;
    r_eventHandleReady: tHandle;
    r_eventRunning: tHandle;
    //
    r_classInstance: unaThread;
    r_classInstanceLocked: bool;
    r_classInstanceInvalid: bool;
  end;

var
  g_threads: array[0..c_max_threads - 1] of unaThreadRec;
  g_freeThreads: array[0..c_max_threads - 1] of byte;
  g_threadsGate: unaInProcessGate;


const
  c_threadSpotIsFree	 = 0;
  c_threadSpotIsBusy	 = 1;

// --  --
function getThreadGlobalIndex(): unsigned;
var
  ok: bool;
  pos: pointer;
begin
  result := $FFFFFFFF;
  //
  if (nil <> g_threadsGate) then
    ok := g_threadsGate.enter(300)
  else
    ok := true;
  //
  if (ok) then begin
    //
    try
      // locate free thread spot
      pos := mscanb(@g_freeThreads, sizeOf(g_freeThreads), c_threadSpotIsFree);
      if (nil <> pos) then begin
	//
	result := (UIntPtr(pos) - UIntPtr(@g_freeThreads));
	//
	g_freeThreads[result] := c_threadSpotIsBusy;
	//
	g_threads[result].r_lockCount := 1;
	g_threads[result].r_classInstance := nil;
	g_threads[result].r_classInstanceLocked := false;
	g_threads[result].r_classInstanceInvalid := true;
      end;
      //
    finally
      //
      if (nil <> g_threadsGate) then
	g_threadsGate.leave();
    end;
  end;
end;

// --  --
function lockThreadInstance(index: unsigned; ensureNotNil: bool): bool;
var
  ok: bool;
begin
  result := false;
  //
  if (nil <> g_threadsGate) then
    ok := g_threadsGate.enter(1000)
  else
    ok := true;
  //
  if (ok) then begin
    //
    try
      //
      result := not g_threads[index].r_classInstanceLocked and
		(not ensureNotNil or (not g_threads[index].r_classInstanceInvalid and (nil <> g_threads[index].r_classInstance)));
      //
      if (result) then
	g_threads[index].r_classInstanceLocked := true;
      //
    finally
      //
      if (nil <> g_threadsGate) then
	g_threadsGate.leave();
    end;
  end;
end;

// --  --
procedure unlockThreadInstance(index: unsigned);
var
  ok: bool;
begin
  if (nil <> g_threadsGate) then
    ok := g_threadsGate.enter(1000)
  else
    ok := true;
  //
  if (ok) then begin
    //
    try
      //
      g_threads[index].r_classInstanceLocked := false;
      //
    finally
      if (nil <> g_threadsGate) then
	g_threadsGate.leave();
    end;
  end;
end;


// --  --
procedure releaseThreadIndex(index: unsigned; releaseInstance: bool);
begin
  if (2 > g_threads[index].r_lockCount) then begin
    //
    g_threads[index].r_lockCount := 0;
    g_threads[index].r_eventStop := 0;
    g_threads[index].r_eventHandleReady := 0;
    g_threads[index].r_eventRunning := 0;
  end
  else
    dec(g_threads[index].r_lockCount);
  //
  if (releaseInstance) then begin
    //
    if (lockThreadInstance(index, false)) then begin
      //
      try
	// clear class instance reference
	g_threads[index].r_classInstance := nil;
	//
      finally
	unlockThreadInstance(index);
      end;
    end;
    //
    g_threads[index].r_classInstanceInvalid := true;	// make sure instance will be no longer used
  end;
  //
  if (0 = g_threads[index].r_lockCount) then
    g_freeThreads[index] := c_threadSpotIsFree;
end;


{ unaThread }

// --  --
procedure unaThread.AfterConstruction();
begin
  inherited;
  //
  if (f_initialActive) then
    start();
end;

// --  --
procedure unaThread.askStop();
begin
  if (grantStop()) then begin
    //
    g_threads[f_globalThreadIndex].r_shouldStop := true;
    wakeUp();
  end;
end;

// -- --
procedure unaThread.BeforeDestruction();
begin
  stop();
  //
  inherited;
  //
  releaseThreadIndex(f_globalThreadIndex, true);
  //
  freeAndNil(f_eventStop);
  freeAndNil(f_eventHandleReady);
  freeAndNil(f_eventRunning);
  freeAndNil(f_sleepEvent);
  freeAndNil(f_gate);
end;

// --  --
constructor unaThread.create(active: bool; priority: int {$IFDEF DEBUG}; const title: string{$ENDIF});
begin
  f_globalThreadIndex := getThreadGlobalIndex();
  //
  if ($FFFFFFFF = f_globalThreadIndex) then
    abort;	// no more threads
  //
{$IFDEF DEBUG }
  f_title := title;
{$ENDIF DEBUG }
  f_initialActive := active;
  //
  f_eventStop := unaEvent.create(true);
  f_eventHandleReady := unaEvent.create();
  f_eventRunning := unaEvent.create();
  //
  f_sleepEvent := unaEvent.create();
  //
  f_defaultStopTimeout := 3000;	// wait 3 seconds for thread to stop
  //
  f_gate := unaInProcessGate.create({$IFDEF DEBUG}self._classID + '(' + title + '.f_gate)'{$ENDIF});
  //
  doSetStatus(unatsStopped);
  g_threads[f_globalThreadIndex].r_priority := priority;
  g_threads[f_globalThreadIndex].r_shouldStop := false;
  g_threads[f_globalThreadIndex].r_handle := 0;	// no thread handle yet
  g_threads[f_globalThreadIndex].r_threadId := 0;	// no thread ID handle yet
  //
  g_threads[f_globalThreadIndex].r_eventStop := f_eventStop.handle;
  g_threads[f_globalThreadIndex].r_eventHandleReady := f_eventHandleReady.handle;
  g_threads[f_globalThreadIndex].r_eventRunning := f_eventRunning.handle;
  //
  g_threads[f_globalThreadIndex].r_classInstance := self;
  g_threads[f_globalThreadIndex].r_classInstanceInvalid := false;
  //
  inherited create();
end;

// --  --
procedure unaThread.doSetStatus(value: unaThreadStatus);
begin
  g_threads[f_globalThreadIndex].r_status := value;
end;

// -- --
function unaThread.enter(timeout: unsigned): bool;
begin
  result := f_gate.enter(timeout{$IFDEF DEBUG}, self._classID{$ENDIF});
end;

// -- --
function unaThread.execute(globalIndex: unsigned): int;
begin
  if (assigned(f_onExecute)) then
    result := f_onExecute(self)
  else
    result := 0;	// return from thread immediately
end;

// -- --
function unaThread.getHandle(): tHandle;
begin
  result := g_threads[f_globalThreadIndex].r_handle;
end;

// -- --
function unaThread.getPriority(): int;
begin
  result := g_threads[f_globalThreadIndex].r_priority;
end;

// -- --
function unaThread.getShouldStop(): bool;
begin
  result := g_threads[f_globalThreadIndex].r_shouldStop;
end;

// -- --
function unaThread.getStatus(): unaThreadStatus;
begin
  result := g_threads[f_globalThreadIndex].r_status;
end;

// -- --
function unaThread.getThreadId(): unsigned;
begin
  result := g_threads[f_globalThreadIndex].r_threadId;
end;

// -- --
function unaThread.grantStart(): bool;
begin
  result := true;
end;

// -- --
function unaThread.grantStop(): bool;
begin
  result := true;
end;

// -- --
class function unaThread.g_shouldStop(threadIndex: unsigned): bool;
begin
  result := g_threads[threadIndex].r_shouldStop;
end;

// -- --
procedure unaThread.leave();
begin
  f_gate.leave();
end;

// -- --
function unaThread.onPause(): bool;
begin
  result := (unatsPaused = getStatus());
end;

// -- --
function unaThread.onResume(): bool;
begin
  result := (unatsRunning = getStatus());
end;

// -- --
function unaThread.pause(): bool;
begin
  if (unatsRunning = getStatus()) then begin
    //
    if (unsigned(-1) <> SuspendThread(getHandle())) then
      doSetStatus(unatsPaused);
  end;
  //
  result := onPause();
end;

// -- --
function unaThread.resume(): bool;
begin
  wakeUp();	// in case the thead was speeping
  //
  if (unatsPaused = getStatus()) then begin
    //
    if (unsigned(-1) <> ResumeThread(getHandle())) then
      doSetStatus(unatsRunning);
  end;
  //
  result := onResume();
end;


// -- --
function thread_func(param: unsigned): unsigned; stdcall;
var
  ok: BOOL;
begin
  try
    // -- enter execute cycle --
    if (unatsBeforeRunning = g_threads[param].r_status) then begin
      //
      // wait until thread handle will be assigned
      // (it is not a global failure if no thread hanlde will be assigned)
      WaitForSingleObject(g_threads[param].r_eventHandleReady, 2000);
      //
    {$IFDEF UNA_NO_THREAD_PRIORITY }
      ok := true;
    {$ELSE}
      ok := SetThreadPriority(g_threads[param].r_handle, g_threads[param].r_priority);
    {$ENDIF}
      //
      if (not ok) then begin
	//
	{$IFDEF LOG_UNACLASSES_INFOS }
	logMessage('thread_func(' + int2str(param) + ') - setThreadPriority() fails for threadId=' + int2str(g_threads[param].r_threadId));
	{$ENDIF LOG_UNACLASSES_INFOS }
      end;
      //
      { This should be set before calling startIn(), so thread will know we are running already
      }
      g_threads[param].r_status := unatsRunning;
      //
      {
	NOTE: some initialization code may be executed in startIn().
	Therefore we should not set the f_eventRun until startIn() returns.
	Failure to ensure this may lead to data loss, due to initialization
	code executed _after_ thread is assumed to be started.
      }
      if (lockThreadInstance(param, true)) then begin
	//
	try
	  g_threads[param].r_classInstance.startIn();
	finally
	  unlockThreadInstance(param);
	end;
      end;
      //
      SetEvent(g_threads[param].r_eventRunning);	// notfiy we are up and running
      //
      // -- execute --
      try
	if (lockThreadInstance(param, true)) then begin
	  //
	  try
	    result := g_threads[param].r_classInstance.execute(param);
	  finally
	    unlockThreadInstance(param);
	  end;
	  //
	end
	else
	  result := $FFFFFFFF;
	//
      except
    {$IFDEF __SYSUTILS_H_ }
	//
	// Delphi does not handle exceptions in other threads
	//
	on E:Exception do begin
	  //
	  {$IFDEF LOG_UNACLASSES_ERRORS }
	  logMessage('thread_func([threadId=' + int2str(GetCurrentThreadId()) + ', globalId=' + int2str(param) + ']) - exception: "' + string(E.Message) + '"');
	  {$ENDIF LOG_UNACLASSES_ERRORS }
	  //
	  result := $FFFFFFFF;
	end;
    {$ELSE }
	// no SysUtils
	result := $FFFFFFFF;
    {$ENDIF }
      end;

      if (lockThreadInstance(param, true)) then begin
	//
	try
	  g_threads[param].r_classInstance.startOut();
	finally
	  unlockThreadInstance(param);
	end;
      end;
      //
    end
    else begin
      //
      // for some reason thread is not going to be started, exit now
      result := 0;
    end;
    //
  finally
    //
    g_threads[param].r_status := unatsStopped;
    //
    if (0 <> g_threads[param].r_handle) then
      CloseHandle(g_threads[param].r_handle);
    //
    releaseThreadIndex(param, false);	// release one lock from thread spot
    //
    // even if event and thread handles were already closed, Windows will know about that
    SetEvent(g_threads[param].r_eventStop);
  end;
end;

// --  --
procedure unaThread.setDefaultStopTimeout(value: unsigned);
begin
  f_defaultStopTimeout := value;
end;

// --  --
procedure unaThread.setPriority(value: int);
{$IFDEF UNA_NO_THREAD_PRIORITY }
{$ELSE }
var
  ok: BOOL;
{$ENDIF UNA_NO_THREAD_PRIORITY }
begin
{$IFDEF UNA_NO_THREAD_PRIORITY }
  g_threads[f_globalThreadIndex].r_priority := value;
{$ELSE}
  {$IFDEF LOG_UNACLASSES_INFOS }
  ok := true;
  {$ENDIF LOG_UNACLASSES_INFOS }
  if (priority <> value) then begin
    //
    if (unatsRunning = getStatus()) then begin
      //
      ok := SetThreadPriority(getHandle(), value);
      if (ok) then
	g_threads[f_globalThreadIndex].r_priority := value;
    end
    else
      g_threads[f_globalThreadIndex].r_priority := value;
  end;
  //
  {$IFDEF LOG_UNACLASSES_INFOS }
  if (not ok) then
    logMessage(self._classID + '.setPriority(' + int2str(value) + ') fails.');
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
{$ENDIF UNA_NO_THREAD_PRIORITY }
end;

// --  --
class function unaThread.shouldStopThread(globalIndex: unsigned): bool;
begin
  result := g_threads[globalIndex].r_shouldStop;
end;

// --  --
function unaThread.sleepThread(value: unsigned): bool;
begin
  result := f_sleepEvent.waitFor(value);
end;

// --  --
function unaThread.start(timeout: unsigned): bool;
begin
  case (getStatus()) of

    unatsRunning:
	// nothing to do
    ;

    unatsBeforeRunning:
	// nothing to do
    ;

    unatsStopping: begin
      // try to stop the thread once more time
      stop();
      //
      if (unatsStopped = getStatus()) then
	// we are lucky today!
	start();
    end;

    unatsStopped: begin
      //
      if (enter(timeout)) then begin
	try
	  //
	  if (grantStart()) then begin
	    //
	    doSetStatus(unatsBeforeRunning);
	    //
	    f_eventRunning.setState(false);
	    f_eventStop.setState(false);
	    //
	    g_threads[f_globalThreadIndex].r_shouldStop := false;
	    //
	    f_eventHandleReady.setState(false);
	    f_sleepEvent.setState(false);
	    //
	    // must do that here, or thread_func could not have a chance to do it
	    inc(g_threads[f_globalThreadIndex].r_lockCount);
	    //
	    g_threads[f_globalThreadIndex].r_handle := CreateThread(nil, 0, @thread_func, pointer(f_globalThreadIndex), 0, g_threads[f_globalThreadIndex].r_threadId);
	    f_eventHandleReady.setState(true);
	    //
	    // wait for thread to be strated
	    // some code may assume that certain data was initialized when start() returns,
	    // so we should wait for this event
	    f_eventRunning.waitFor(timeout);
	    //
	    // unatsRunning status will be assigned inside thread_func
	  end;
	  //
	finally
	  leave();
	end;
	//
      end;
    end;

    unatsPaused: begin
      //
      g_threads[f_globalThreadIndex].r_shouldStop := false;
      resume();
    end;

  end;
  //
  result := (getStatus() in [unatsRunning, unatsBeforeRunning]);
  //
{$IFDEF PACKET_DEBUG}
  infoMessage('thread status = ' + int2Str(ord(f_status)));
{$ENDIF}
end;

// -- --
procedure unaThread.startIn();
begin
  //
end;

// -- --
procedure unaThread.startOut();
begin
  //
end;

// -- --
function unaThread.stop(timeout: unsigned; force: bool): bool;
var
  kill: bool;
begin
  if (nil = self) then begin
    //
    result := true;
    exit;
  end;
  //
  if (INFINITE = timeout) then
    timeout := f_defaultStopTimeout;
  //
  case (getStatus()) of

    unatsStopping,
    unatsRunning,
    unatsBeforeRunning: begin
      //
      doSetStatus(unatsStopping);
      //
      if (force or grantStop()) then begin
	//
	kill := force;
	//
	g_threads[f_globalThreadIndex].r_shouldStop := true;
	wakeUp();
	//
	if (g_threads[f_globalThreadIndex].r_threadId = GetCurrentThreadId()) then begin
	  //
	  // we are stopping from the same thread
	  // no other actions are required
	  //
	  kill := false;
	end
	else begin
	  //
	  if (enter(timeout)) then begin
	    //
	    try
	      if (0 < timeout) then begin
		//
		if (f_eventStop.waitFor(timeout)) then begin
		  //
		  g_threads[f_globalThreadIndex].r_shouldStop := false;	// thread was stopped
		  kill := false;
		end
		else
		  {$IFDEF LOG_UNACLASSES_ERRORS }
		  logMessage(self._classID + '.stop(' + int2str(timeout) + ') - timeout on stop.');
		  {$ENDIF LOG_UNACLASSES_ERRORS }
		//
	      end
	      else
		{$IFDEF LOG_UNACLASSES_ERRORS }
		logMessage(self._classID + '.stop(' + int2str(timeout) + ') - invlaid timeout value.');
		{$ENDIF LOG_UNACLASSES_ERRORS }
                ;
	      //
	    finally
	      leave();
	    end;
	    //
	  end
	  else
	    {$IFDEF LOG_UNACLASSES_ERRORS }
	    logMessage(self._classID + '.stop(' + int2str(timeout) + ') - cannot enter the gate.');
	    {$ENDIF LOG_UNACLASSES_ERRORS }
	end;
	//
	if (kill) then begin
	  //
	  TerminateThread(g_threads[f_globalThreadIndex].r_handle, 1973);
	  //
	  g_threads[f_globalThreadIndex].r_status := unatsStopped;
	  g_threads[f_globalThreadIndex].r_shouldStop := false;	// thread was stopped
	  //
	  if (0 <> g_threads[f_globalThreadIndex].r_handle) then
	    CloseHandle(g_threads[f_globalThreadIndex].r_handle);
	  //
	  releaseThreadIndex(f_globalThreadIndex, false);	// release one lock from thread spot
	  //
	  // even if event and thread handles were already closed, Windows will know about that
	  SetEvent(g_threads[f_globalThreadIndex].r_eventStop);
	end;
      end
      else
	{$IFDEF LOG_UNACLASSES_ERRORS }
	logMessage(self._classID + '.stop(' + int2str(timeout) + ') - stop was not granted.');
	{$ENDIF LOG_UNACLASSES_ERRORS }
    end;

    unatsPaused: begin
      //
      if (resume()) then begin
	//
	if (unatsPaused <> getStatus()) then begin
	  //
	  stop(timeout);
	end
	else begin
	  //
	  // resume was not successfull, thread is still paused, make it stop anyways
	  ResumeThread(getHandle());
	  //
	  doSetStatus(unatsRunning);
	  //
	  stop();
	end;
      end
      else
	doSetStatus(unatsStopping);
    end;

    unatsStopped:
	// nothing to do
    ;

  end;
  //
  result := (getStatus() in [unatsStopping, unatsStopped]);
end;

// -- --
procedure unaThread.wakeUp();
begin
  f_sleepEvent.setState();
end;


{ unaThreadManager }

// -- --
function unaThreadManager.add(thread: unaThread): unsigned;
begin
  result := f_threads.add(thread);
  thread.f_manager := self;
end;

// -- --
procedure unaThreadManager.clear();
begin
  stop();
  if (f_master) then
    enumExecute(1);
  //
  f_threads.clear();
end;

// -- --
constructor unaThreadManager.create(master: bool);
begin
  f_master := master;
  //
  f_gate := unaInProcessGate.create({$IFDEF DEBUG}self._classID + '(f_gate)'{$ENDIF});
  f_threads := unaList.create();
end;

// -- --
destructor unaThreadManager.Destroy();
begin
  inherited;
  //
  clear();
  freeAndNil(f_threads);
  freeAndNil(f_gate);
end;

// --  --
function unaThreadManager.enumExecute(action: unsigned; param: unsigned): unsigned;
var
  i: unsigned;
  t: unaThread;
begin
  result := 0;
  //
  if (f_gate.enter(1000{$IFDEF DEBUG}, self._classID{$ENDIF})) then
    try
      //
      if (f_threads.count > 0) then
	//
	for i := 0 to f_threads.count -1 do begin
	  t := get(i);
	  if (t <> nil) then
	    case action of
	      1: begin
		freeAndNil(t);
		Inc(result);
	      end;
	      2:
		if (t.pause()) then
		  Inc(result);
	      3:
		if (t.resume()) then
		  Inc(result);
	      4:
		if (t.start()) then
		  Inc(result);
	      5:
		if (t.stop(param)) then
		  Inc(result);
	      6: begin
		t.stop(0);
		Inc(result);
	      end;
	    end;
	end;
    finally
      f_gate.leave();
    end;
end;

// -- --
function unaThreadManager.get(index: unsigned): unaThread;
begin
  result := f_threads.get(index);
end;

// -- --
function unaThreadManager.getCount(): unsigned;
begin
  result := f_threads.count;
end;

// -- --
procedure unaThreadManager.pause();
begin
  enumExecute(2);
end;

// -- --
procedure unaThreadManager.remove(index: unsigned);
var
  t: unaThread;
begin
  t := get(index);
  //
  if (t <> nil) then begin
    //
    if (f_master) then
      freeAndNil(t)
    else
      t.f_manager := nil;
  end;    
  //
  f_threads.removeByIndex(index);
end;

// -- --
procedure unaThreadManager.resume();
begin
  enumExecute(3);
end;

// -- --
procedure unaThreadManager.start();
begin
  enumExecute(4);
end;

// --  --
function unaThreadManager.stop(timeout: unsigned = INFINITE): bool;
begin
  enumExecute(6);
  result := (enumExecute(5, timeout) = getCount());
end;

{ unaSleepyThread }

// --  --
constructor unaSleepyThread.create(active: bool);
begin
  inherited create(active, THREAD_PRIORITY_IDLE);
end;

// --  --
procedure unaSleepyThread.dummyJob();
var
  i: int;
  d: double;
begin
  move(pArray(f_mem)[0], pArray(f_mem)[1], 65535);
  //
  d := pi;
  //
  for i := 1 to 10000 do
    d := d * 1.23456789;
end;

// --  --
function unaSleepyThread.execute(globalIndex: unsigned): int;
var
  cpu: int64;
  newCPU: unsigned;
  myTime: int64;
begin
  f_minCPU := -1;
  f_maxCPU := 0;
  f_mem := malloc(65536);
  //
  f_stones := 0;
  priority := THREAD_PRIORITY_TIME_CRITICAL;
  try
    myTime := timeMark();
    repeat
      //
      cpu := timeMark();
      dummyJob();
      cpu := timeElapsed64ticks(cpu);
      //
      if ((f_minCPU > cpu) or (-1 = f_minCPU)) then
	f_minCPU := cpu;
      //
      if (f_maxCPU < cpu) then
	f_maxCPU := cpu;
      //
      inc(f_stones);
      //
    until (1500 < timeElapsed32(myTime));
    //
  finally
    priority := THREAD_PRIORITY_LOWEST;
  end;
  //
  while (not shouldStop) do begin
    //
    myTime := timeMark();
    dummyJob();
    //
    cpu := timeElapsed64ticks(myTime);
    if (cpu > f_maxCPU) then begin
      //
      inc(f_maxCPU, f_maxCPU div 10000);
      cpu := f_maxCPU;
    end;
    //
    if (cpu < f_minCPU) then begin
      //
      dec(f_minCPU, f_minCPU div 10000);
      cpu := f_minCPU;
    end;
    //
    sleepThread(600);
    //
    newCPU := percent(cpu - f_minCPU, f_maxCPU - f_minCPU);
    if (newCPU > f_cpuUsage) then
      f_cpuUsage := f_cpuUsage + (newCPU - f_cpuUsage) div 2
    else
      f_cpuUsage := f_cpuUsage - (f_cpuUsage - newCPU) div 2;
    //
  end;
  //
  mrealloc(f_mem);
  //
  result := 1;
end;


{ unaAbstractTimer }

// --  --
procedure unaAbstractTimer.AfterConstruction();
begin
  inherited;
  //
  interval := f_interval;
end;

// --  --
procedure unaAbstractTimer.BeforeDestruction();
begin
  inherited;
  //
  stop();
  //
  freeAndNil(f_gate);
end;

// --  --
procedure unaAbstractTimer.changeInterval(var newValue: unsigned);
begin
  // nothing here
end;

// --  --
constructor unaAbstractTimer.create(interval: unsigned{$IFDEF DEBUG}; const title: string{$ENDIF});
begin
  inherited create();
  //
{$IFDEF DEBUG}
  f_title := title;
{$ENDIF}
  //
  f_gate := unaInProcessGate.create({$IFDEF DEBUG}self._classID + '(' + title + '.f_gate)'{$ENDIF});
  f_interval := interval;
end;

// --  --
procedure unaAbstractTimer.doSetInterval(value: unsigned);
var
  wasRunning: bool;
begin
  if (f_interval <> value) then begin
    //
    wasRunning := isRunning();
    //
    stop();
    //
    try
      changeInterval(value);
      f_interval := value;
    finally
      //
      if (wasRunning) then
	start();
    end;
  end;
end;

// --  --
procedure unaAbstractTimer.doStop();
begin
  if (enter(5000)) then
    try
      // just to make sure we are not inside timer() proc
      f_gate := f_gate;
    finally
      leave();
    end;
end;

// --  --
procedure unaAbstractTimer.doTimer();
begin
  if (not f_isPaused) then begin
    //
    if (enter(interval shr 1)) then begin
      try
	try
	  timer();
	  //
	  if (assigned(f_onTimerEvent)) then
	    f_onTimerEvent(self);
	except
	  // ignore exceptions
	end;
	//
      finally
	leave();
      end;
    end;
  end;
end;

// --  --
function unaAbstractTimer.enter(timeout: unsigned): bool;
begin
  result := f_gate.enter(timeout{$IFDEF DEBUG}, self._classID{$ENDIF});
end;

// --  --
function unaAbstractTimer.isRunning(): bool;
begin
  result := f_isRunning;
end;

// --  --
procedure unaAbstractTimer.leave();
begin
  f_gate.leave();
end;

// --  --
procedure unaAbstractTimer.pause();
begin
  if (isRunning()) then
    f_isPaused := true;
end;

// --  --
procedure unaAbstractTimer.resume();
begin
  f_isPaused := false;
end;

// --  --
procedure unaAbstractTimer.start();
begin
  if (not isRunning()) then
    f_isRunning := doStart();
  //
  if (isRunning() and f_isPaused) then
    resume();
end;

// --  --
procedure unaAbstractTimer.stop();
begin
  if (isRunning()) then begin
    //
    doStop();
    //
    f_isRunning := false;
  end;
end;

// --  --
procedure unaAbstractTimer.timer();
begin
  // nothing here
end;


{ unaTimer }

// --  --
procedure timerProc(wnd: hWnd; msg: UINT; event: DWORD; time: DWORD); stdcall;
var
  timer: unaTimer absolute event;
begin
  if (nil <> timer) then
    timer.doTimer();
end;

// --  --
function unaTimer.doStart(): bool;
begin
  f_timer := SetTimer(0, UINT(self), interval, @timerProc);
  result := true;
end;

// --  --
procedure unaTimer.doStop();
begin
  KillTimer(0, f_timer);
end;


{ unaTimerThread }

// --  --
constructor unaTimerThread.create(timer: unaThreadedTimer; active: bool; priority: int);
begin
  f_timer := timer;
  //
  inherited create(active, priority);
end;

// --  --
function unaTimerThread.execute(globalIndex: unsigned): int;
begin
  f_timer.execute(self);
  //
  f_timer.f_isRunning := false;
  result := 0;
end;


{ unaThreadedTimer }

// --  --
procedure unaThreadedTimer.AfterConstruction();
begin
  inherited;
  //
  if (f_active) then
    start();
end;

// --  --
constructor unaThreadedTimer.create(interval: unsigned; active: bool; priority: int);
begin
  f_thread := unaTimerThread.create(self, false, priority);
  //
  inherited create(interval);
  //
  f_active := active;
end;

// --  --
destructor unaThreadedTimer.Destroy();
begin
  inherited;
  //
  freeAndNil(f_thread);
end;

// --  --
function unaThreadedTimer.doStart(): bool;
begin
  f_thread.start();
  result := true;
end;

// --  --
procedure unaThreadedTimer.doStop();
begin
  f_thread.stop();
end;

// --  --
function unaThreadedTimer.getPriority(): unsigned;
begin
  result := f_thread.priority;
end;

// --  --
procedure unaThreadedTimer.setPriority(value: unsigned);
begin
  f_thread.priority := value;
end;


{ unaThreadTimer }

// --  --
procedure unaThreadTimer.execute(thread: unaTimerThread);
var
  mark: int64;
  elapsed: unsigned;
  delta: int;
  subSleepTotal: unsigned;
  subSleep: unsigned;
begin
  mark := timeMark();
  delta := 0;
  subSleepTotal := 0;
  //
  while (not thread.shouldStop) do begin
    //
    try
      if (delta < int(interval - subSleepTotal) - 20) then begin
	//
	subSleep := min(int(interval - subSleepTotal) - delta - 20, 100);
	thread.sleepThread(subSleep);
	inc(subSleepTotal, subSleep);
      end
      else
	thread.sleepThread(1);
      //
      elapsed := timeElapsed32(mark);
      if (not thread.shouldStop and (int(elapsed) >= int(interval) - delta)) then begin
	//
	doTimer();
	delta := int(timeElapsed32(mark)) - (int(interval) - delta);
	mark := timeMark();
	subSleepTotal := 0;
      end;
      //
    except
      // ignore exceptions
    end;
  end;
end;


{ unaWaitableTimer }

// --  --
constructor unaWaitableTimer.create(interval: unsigned);
begin
  f_handle := CreateWaitableTimer(nil, FALSE, nil);
  //
  inherited create(interval);
end;

// --  --
destructor unaWaitableTimer.Destroy();
begin
  inherited;
  //
  CloseHandle(f_handle);
end;

// --  --
function unaWaitableTimer.doStart(): bool;
var
  dueTime: int64;
begin
  f_firstTime := true;
  dueTime := 0;               
  SetWaitableTimer(f_handle, dueTime, interval, nil, nil, FALSE);
  //
  result := inherited doStart();
end;

// --  --
procedure unaWaitableTimer.doStop();
begin
  CancelWaitableTimer(f_handle);
end;

// --  --
procedure unaWaitableTimer.execute(thread: unaTimerThread);
begin
  while (not thread.shouldStop) do begin
    //
    try
      if (waitForObject(f_handle)) then begin
	//
	if (f_firstTime) then
	  f_firstTime := false
	else
	  doTimer();
	//
      end;
    except
      // ignore exceptions
    end;
  end;
end;


{ unaRandomGenThread }

// --  --
procedure unaRandomGenThread.AfterConstruction();
begin
  f_values := unaList.create();
  //
  f_nextValue := 0;
  f_nextValueBitsValid := 0;
  f_nextValueBitsMax := sizeOf(f_nextValue) shl 3;	// 32 or 64
  //
  inherited;
end;

// --  --
procedure unaRandomGenThread.BeforeDestruction;
begin
  inherited;
end;

constructor unaRandomGenThread.create(aheadGenSize: unsigned; active: bool; priority: int);
begin
  f_aheadGenSize := aheadGenSize;	// generate up to this value of random values ahead
  //
  inherited create(active, priority);
end;

// --  --
destructor unaRandomGenThread.Destroy();
begin
  inherited;
  //
  freeAndNil(f_values);
end;

// --  --
function unaRandomGenThread.execute(globalId: unsigned): int;
var
  ticks: int64;
begin
  while (not shouldStop) do begin
    //
    if (int(f_aheadGenSize) > f_values.count) then begin
      //
      sleepThread(7);
      //
      ticks := timeElapsed64ticks(f_timeMark);
      //
      inc(f_nextValueBitsValid, 2);
      f_nextValue := unsigned((f_nextValue or (ticks and $3)) shl 2);	// get two last bits from elapsed interval and shift as needed
      //
      if (f_nextValueBitsValid >= f_nextValueBitsMax) then begin
	//
	// we have enough bits to form a new vlaue
	feed(f_nextValue);
	//
	f_nextValue := 0;
	f_nextValueBitsValid := 0;	// start over
      end;
      //
    end
    else
      sleepThread(1000);	// since we have enough random values ahead, do sleep well, thread will be waken up as needed
    //
  end;
  //
  result := 0;
end;

// --  --
function unaRandomGenThread.feed(value: unsigned): bool;
begin
  result := (f_values.count < int(f_aheadGenSize));
  //
  if (result) then begin
    //
    f_values.add(int(value));
    //
    //f_waitTime := 0;	// reset waiting time -- not so good idea
  end;    
end;

// --  --
function unaRandomGenThread.getValuesInCacheNum(): unsigned;
begin
  result := f_values.count;
end;

// --  --
function unaRandomGenThread.random(upperLimit: uint32; maxTimeout: int): uint32;
var
  timeout: int;
  mark: int64;
begin
  mark := timeMark();
  //
  if (0 > maxTimeout) then
    timeout := 10000
  else
    timeout := maxTimeout;
  //
  if (enter(timeout)) then begin
    //
    try
      //
      if (2 > upperLimit) then begin
	//
	if (1 > upperLimit) then
	  result := 0	// the only possible value
	else
	  result := (timeElapsed64ticks(mark) and $1);	// return 0 or 1
	//
      end
      else begin
	//
	while ((unatsRunning = getStatus()) and (1 > f_values.count) and (timeout > int(timeElapsed32(mark)))) do
	  f_values.waitForData(min(100, timeout));
	//
	if (lockNonEmptyList(f_values)) then begin
	  try
	    //
	    result := trunc(uint32(f_values[0]) / (high(unsigned) / upperLimit));
	    f_values.removeFromEdge(true);
	    //
	    wakeUp();	// produce some more values
	  finally
	    f_values.unlock();
	  end;
	end
	else begin
	  //
	  if (0 > maxTimeout) then
	    result := high(result)	// some error
	  else begin
	    //
	    randomize();
	    result := uint32(System.random(int(upperLimit)));	// return pseudo-random value rather than error
	    //
	    inc(f_pseudoFeeds);
	  end;
	end;
	//
      end;
      //
    finally
      leave();
    end;
  end
  else begin
    //
    if (0 > maxTimeout) then
      result := high(result)	// some error
    else begin
      //
      randomize();
      result := System.random(upperLimit);	// return pseudo-random value rather than error
      //
      inc(f_pseudoFeeds);
    end;
  end;
  //
  f_waitTime := timeElapsed64(mark);
  inc(f_waitTimeTotal, f_waitTime);
end;

// --  --
procedure unaRandomGenThread.startIn();
begin
  f_timeMark := timeMark();
  f_waitTimeTotal := 0;
  f_pseudoFeeds := 0;
  //
  inherited;
end;

// --  --
procedure unaRandomGenThread.startOut();
begin
  inherited;
end;


{ unaIniAbstractStorage }

// --  --
procedure unaIniAbstractStorage.AfterConstruction();
begin
  inherited;
  //
  f_gate := unaInProcessGate.create();
end;

// --  --
procedure unaIniAbstractStorage.BeforeDestruction();
begin
  inherited;
  //
  freeAndNil(f_gate);
end;

// --  --
constructor unaIniAbstractStorage.create(const section: string; lockTimeout: unsigned);
begin
  inherited create();
  //
  f_lockTimeout := lockTimeout;
  f_section := section;
end;

// --  --
function unaIniAbstractStorage.enter(const section: string; out sectionSave: string; timeout: unsigned): bool;
begin
  if (0 = timeout) then
    timeout := f_lockTimeout;
  //
  result := f_gate.enter(timeout);
  //
  if (result and ('' <> section)) then begin
    //
    sectionSave := self.section;
    self.section := section;
  end;
end;

// --  --
function unaIniAbstractStorage.enter(const section: string; timeout: unsigned): bool;
var
  sectionSave: string;
begin
  result := enter(section, sectionSave, timeout);
end;

// --  --
function unaIniAbstractStorage.get(const key, defValue: string): string;
begin
  result := getStringValue(key, defValue);
end;

{$IFDEF __BEFORE_DC__ }

{$IFDEF __AFTER_D5__ }

// --  --
function unaIniAbstractStorage.get(const key: string; const defValue: wString): wString;
begin
  result := getStringValue(key, aString(defValue));
end;

{$ENDIF __AFTER_D5__ }

{$ELSE }

// --  --
function unaIniAbstractStorage.get(const key: string; const defValue: aString): aString;
begin
  result := aString(getStringValue(key, string(defValue)));
end;

{$ENDIF __BEFORE_DC__ }

// --  --
function unaIniAbstractStorage.get(const key: string; defValue: boolean): bool;
begin
  result := getBool(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get(const key: string; defValue: int): int;
begin
  result := getInt(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get(const key: string; defValue: unsigned): unsigned;
begin
  result := getUnsigned(key, defValue);
end;

{$IFNDEF CPU64 }

// --  --
function unaIniAbstractStorage.get(const key: string; defValue: int64): int64;
begin
  result := getInt64(key, defValue);
end;

{$ENDIF CPU64 }

// --  --
function unaIniAbstractStorage.get(const section, key: string; defValue: unsigned): unsigned;
begin
  result := getUnsigned(section, key, defValue);
end;

// --  --
function unaIniAbstractStorage.get(const section, key: string; defValue: int): int;
begin
  result := getInt(section, key, defValue);
end;

// --  --
function unaIniAbstractStorage.get(const section, key, defValue: string): string;
begin
  result := getStringSectionKey(section, key, defValue);
end;

{$IFDEF __BEFORE_DC__ }

{$IFDEF __AFTER_D5__ }

// --  --
function unaIniAbstractStorage.get(const section, key: string; const defValue: wString): wString;
begin
  result := wString(getStringSectionKey(section, key, aString(defValue)));    // mo magic here
end;

{$ENDIF __AFTER_D5__ }

{$ELSE }

// --  --
function unaIniAbstractStorage.get(const section, key: string; const defValue: aString): aString;
begin
  result := aString(getStringSectionKey(section, key, string(defValue)));    // mo magic here
end;

{$ENDIF __BEFORE_DC__ }

// --  --
function unaIniAbstractStorage.get(const section, key: string; defValue: boolean): bool;
begin
  result := getBool(section, key, defValue);
end;

{$IFNDEF CPU64 }

// --  --
function unaIniAbstractStorage.get(const section, key: string; defValue: int64): int64;
begin
  result := getInt64(section, key, defValue);
end;

{$ENDIF CPU64 }

// --  --
function unaIniAbstractStorage.getBool(const section, key: string; defValue: bool): bool;
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then begin
    //
    try
      result := getBool(key, defValue);
    finally
      leave(sectionSave);
    end
    //
  end
  else
    result := defValue;
end;

// --  --
function unaIniAbstractStorage.getBool(const key: string; defValue: bool): bool;
begin
  result := str2bool(getStringValue(key, bool2str(defValue)), defValue);
end;

// --  --
function unaIniAbstractStorage.getInt(const key: string; defValue: int): int;
begin
  result := str2intInt(getStringValue(key, int2str(defValue)), defValue);
end;

// --  --
function unaIniAbstractStorage.getInt(const section, key: string; defValue: int): int;
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      result := getInt(key, defValue);
    finally
      leave(sectionSave);
    end
  else
    result := defValue;
end;

// --  --
function unaIniAbstractStorage.getInt64(const key: string; defValue: int64): int64;
begin
  result := str2intInt64(getStringValue(key, int2str(defValue)), defValue);
end;

// --  --
function unaIniAbstractStorage.getInt64(const section, key: string; defValue: int64): int64;
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      result := getInt64(key, defValue);
    finally
      leave(sectionSave);
    end
  else
    result := defValue;
end;

// --  --
function unaIniAbstractStorage.getSection(): string;
begin
  result := f_section;
end;

// --  --
function unaIniAbstractStorage.getSectionAsText(const sectionName: string): string;
begin
  if ('' <> sectionName) then
    result := doGetSectionAsText(sectionName)
  else
    result := doGetSectionAsText(section);
end;

// --  --
function unaIniAbstractStorage.getStringSectionKey(const section, key, defValue: string): string;
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      result := getStringValue(key, defValue);
    finally
      leave(sectionSave);
    end;
end;

// --  --
function unaIniAbstractStorage.getUnsigned(const key: string; defValue: unsigned): unsigned;
begin
  result := str2intUnsigned(getStringValue(key, int2str(defValue)), defValue);
end;

// --  --
function unaIniAbstractStorage.getUnsigned(const section, key: string; defValue: unsigned): unsigned;
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      result := getUnsigned(key, defValue);
    finally
      leave(sectionSave);
    end
  else
    result := defValue;
end;

// --  --
function unaIniAbstractStorage.get_bool(const key: string; defValue: bool): bool;
begin
  result := getBool(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get_int(const key: string; defValue: int): int;
begin
  result := getInt(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get_int64(const key: string; defValue: int64): int64;
begin
  result := getInt64(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get_string(const key, defValue: string): string;
begin
  result := get(key, defValue);
end;

// --  --
function unaIniAbstractStorage.get_unsigned(const key: string; defValue: unsigned): unsigned;
begin
  result := getUnsigned(key, defValue);
end;

// --  --
procedure unaIniAbstractStorage.leave(const sectionSave: string);
begin
  if ('' <> sectionSave) then
    self.section := sectionSave;
  //
  f_gate.leave();
end;

// --  --
procedure unaIniAbstractStorage.setSection(const section: string);
begin
  if (enter()) then begin
    try
      //
      // avoid calling self.section := section here, or it will end up
      // in stack overflow due to endless recursion
      //
      if ('' <> section) then
	f_section := section
      else
	f_section := ' ';	// avoid AV in some implementations of INI file storage
      //
    finally
      leave();
    end;
  end;
end;

// --  --
function unaIniAbstractStorage.setSectionAsText(const sectionName, value: string): bool;
begin
  if ('' <> sectionName) then
    result := doSetSectionAsText(sectionName, value)
  else
    result := doSetSectionAsText(section, value);
end;

// --  --
function unaIniAbstractStorage.setSectionAsText(const value: string): bool;
begin
  result := setSectionAsText('', value);
end;

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; value: int);
begin
  setValue(key, int2str(value));
end;

// --  --
procedure unaIniAbstractStorage.setValue(const key, value: string);
begin
  setStringValue(key, value);
end;

{$IFDEF __BEFORE_DC__ }

{$IFDEF __AFTER_D5__ }

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; const value: wString);
begin
  setStringValue(key, aString(value));
end;

{$ENDIF __AFTER_D5__ }

{$ELSE }

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; const value: aString);
begin
  setStringValue(key, string(value));
end;

{$ENDIF __BEFORE_DC__ }

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; value: boolean);
begin
  setValue(key, bool2str(value));
end;

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; value: unsigned);
begin
  setValue(key, int2str(value));
end;

{$IFNDEF CPU64 }

// --  --
procedure unaIniAbstractStorage.setValue(const key: string; value: int64);
begin
  setValue(key, int2str(value));
end;

{$ENDIF CPU64 }

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; value: unsigned);
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      setValue(key, value);
    finally
      leave(sectionSave);
    end;
end;

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; value: int);
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      setValue(key, value);
    finally
      leave(sectionSave);
    end;
end;

// --  --
procedure unaIniAbstractStorage.setValue(const section, key, value: string);
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      setValue(key, value);
    finally
      leave(sectionSave);
    end;
end;

{$IFDEF __BEFORE_DC__ }

{$IFDEF __AFTER_D5__ }

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; const value: wString);
begin
  setValue(section, key, aString(value));         // no magic here
end;

{$ENDIF __AFTER_D5__ }

{$ELSE }

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; const value: aString);
begin
  setValue(section, key, string(value));         // no magic here
end;

{$ENDIF __BEFORE_DC__ }

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; value: boolean);
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then
    try
      setValue(key, value);
    finally
      leave(sectionSave);
    end;
end;

{$IFNDEF CPU64 }

// --  --
procedure unaIniAbstractStorage.setValue(const section, key: string; value: int64);
var
  sectionSave: string;
begin
  if (enter(section, sectionSave)) then begin
    //
    try
      setValue(key, value);
    finally
      leave(sectionSave);
    end;
  end;
end;

{$ENDIF CPU64 }

// --  --
procedure unaIniAbstractStorage.set_bool(const key: string; value: bool);
begin
  setValue(key, value);
end;

// --  --
procedure unaIniAbstractStorage.set_int(const key: string; value: int);
begin
  setValue(key, value);
end;

// --  --
procedure unaIniAbstractStorage.set_int64(const key: string; value: int64);
begin
  setValue(key, value);
end;

// --  --
procedure unaIniAbstractStorage.set_string(const key, value: string);
begin
  setValue(key, value);
end;

// --  --
procedure unaIniAbstractStorage.set_unsigned(const key: string; value: unsigned);
begin
  setValue(key, value);
end;

// --  --
function unaIniAbstractStorage.waitForValue(const key, value: string; timeout: int): bool;
var
  enterMark: int64;
begin
  enterMark := timeMark();
  //
  while ((timeElapsed64(enterMark) < timeout) and not sameString(get(key, ''), value)) do begin
    //
    sleep(400);
  end;
  //
  result := sameString(get(section, key, ''), value);
end;


{ unaIniFile }

// --  --
procedure unaIniFile.AfterConstruction();
begin
  inherited;
  //
  // causes file name to be assigned if f_fileName is empty
  fileName := f_fileName;
end;

// --  --
constructor unaIniFile.create(const fileName: wString; const section: string; lockTimeout: unsigned; checkFilePath: bool);
begin
  f_fileName := fileName;
  //
  if (checkFilePath) then
    fixFilePath();
  //
  inherited create(section, lockTimeout);
end;

// --  --
function unaIniFile.doGetSectionAsText(const sectionName: string): string;
var
{$IFNDEF NO_ANSI_SUPPORT }
  resA: array[0..16383] of aChar;
{$ENDIF NO_ANSI_SUPPORT }
  resW: array[0..16383] of wChar;
  len: DWORD;
  s, p: int;
{$IFNDEF NO_ANSI_SUPPORT }
  strA: aString;
{$ENDIF NO_ANSI_SUPPORT }
  strW: wString;
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
    //
    len := GetPrivateProfileSectionW(pwChar(wString(sectionName)), resW, sizeOf(resW), pwChar(f_fileName));
    //
    result := '';
    if (0 < len) then begin
      //
      s := 0;
      p := 0;
      while (p < int(len)) do begin
        //
        if (#0 = resW[p]) then begin
          //
          array2str(resW, strW, s, p - s);
          result := result + strW + #13#10;
          s := p + 1;
        end;
        //
        inc(p);
      end;
    end;
{$IFNDEF NO_ANSI_SUPPORT }
  end
  else begin
    //
    len := GetPrivateProfileSectionA(paChar(aString(sectionName)), resA, sizeOf(resA), paChar(aString(f_fileName)));
    //
    result := '';
    if (0 < len) then begin
      //
      s := 0;
      p := 0;
      while (p < int(len)) do begin
        //
        if (#0 = resA[p]) then begin
          //
          array2str(resA, strA, s, p - s);
          result := result + string(strA) + #13#10;
          s := p + 1;
        end;
        //
        inc(p);
      end;
    end;
  end;
{$ENDIF NO_ANSI_SUPPORT }
end;

// --  --
function unaIniFile.doSetSectionAsText(const sectionName, value: string): bool;
var
  res: array[0..16383] of AnsiChar;
  z, s, p: int;
begin
  s := 1;
  p := 1;
  z := 0;
  fillChar(res, sizeOf(res), #255);
  while ( (z < sizeOf(res)) and (p < length(value)) ) do begin
    //
    if (aChar(value[p]) in [#13, #10]) then begin
      //
      if (p > s) then begin
	//
	move(value[s], res[z], p - s);
	inc(z, p - s);
      end;
      res[z] := #0;
      inc(z);
      //
      if (p < length(value)) then
	if (#10 = value[p + 1]) then
	  inc(p);
      //
      s := p + 1;
    end;
    //
    inc(p);
  end;
  //
  res[z] := #0;
  //
  result := WritePrivateProfileSectionA(paChar(aString(sectionName)), paChar(@res), paChar(aString(fileName)));
end;

// --  --
procedure unaIniFile.fixFilePath();
var
  bufW: array[0..MAX_PATH] of wideChar;
{$IFNDEF NO_ANSI_SUPPORT }
  bufA: array[0..MAX_PATH] of AnsiChar;
  len: DWORD;
{$ENDIF NO_ANSI_SUPPORT }
begin
  if (('' <> fileName) and (1 > pos(':', fileName)) and (1 > pos('\', fileName)) and (1 > pos('/', f_fileName)) ) then begin
    //
    if (#1 = fileName) then begin
      //
      f_fileName := extractFileName(getModuleFileNameExt(''));
      f_fileName := f_fileName + '\' + f_fileName + '.ini';
      //
{$IFDEF __BEFORE_D6__ }
      str2arrayW(getAppDataFolderPath(), bufW);
{$ELSE }
      str2array(getAppDataFolderPath(), bufW);
{$ENDIF __BEFORE_D6__ }
    end
    else begin
      //
{$IFNDEF NO_ANSI_SUPPORT }
      if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	GetCurrentDirectoryW(MAX_PATH, bufW)
{$IFNDEF NO_ANSI_SUPPORT }
      else begin
	//
	len := GetCurrentDirectoryA(MAX_PATH, bufA);
	//
	bufW[len] := #0;
	repeat
	  //
	  bufW[len] := wideChar(bufA[len]);
	  //
	  if (0 < len) then
	    dec(len)
	  else
	    break;
	  //
	until (false);
      end;
{$ENDIF NO_ANSI_SUPPORT }
      ;
    end;
    //
    f_fileName := addBackSlash(bufW) + f_fileName;
    unaUtils.forceDirectories(unaUtils.extractFilePath(f_fileName));
  end;
end;

// --  --
function unaIniFile.getAsString(): string;
begin
  // TO DO:
  result := '';
end;

// --  --
function unaIniFile.getStringValue(const key, defValue: string): string;
var
{$IFNDEF NO_ANSI_SUPPORT }
  bufA: array [0..16383] of aChar;
  buf2A: array [0..2] of aChar;
  defA: paChar;
  akeyA: aString;
  pkeyA: paChar;
{$ENDIF NO_ANSI_SUPPORT }
  bufW: array [0..16383] of wChar;
  buf2W: array [0..2] of wChar;
  //
  defString: wString;
  defW: pwChar;
  res: unsigned;
  akeyW: wString;
  pkeyW: pwChar;
begin
  if (enter()) then
    try
      //
      defString := defValue;
{$IFNDEF NO_ANSI_SUPPORT }
      if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
	//
	if ('' = defString) then
	  defW := '0'
	else
	  defW := pwChar(defString);
	//
	akeyW := trimS(key);
	if ('' <> akeyW) then
	  pkeyW := pwChar(akeyW)
	else
	  pkeyW := nil;
	//
	res := GetPrivateProfileStringW(pwChar(f_section), pkeyW, defW, bufW, sizeof(bufW), pwChar(f_fileName));
	if (('' = defString) and (res = 1) and ('0' = bufW[0])) then begin
	  //
	  // check if we got default value or real value
	  defW := '2';
	  //
	  res := GetPrivateProfileStringW(pwChar(f_section), pkeyW, defW, buf2W, sizeof(buf2W), pwChar(f_fileName));
	  if ((1 = res) and ('2' = buf2W[0])) then begin
	    // there is no such key - return default falue
	    result := defValue;
	  end
	  else begin
	    // key exists - return value
	    result := string(bufW);
	  end;
	end
	else
	  result := bufW;
	//
{$IFNDEF NO_ANSI_SUPPORT }
      end
      else begin
	// ANSI version
	if ('' = defString) then
	  defA := '0'
	else
	  defA := paChar(aString(defString));
	//
	akeyA := aString(trimS(key));
	if ('' <> akeyA) then
	  pkeyA := paChar(akeyA)
	else
	  pkeyA := nil;
	//
	res := GetPrivateProfileStringA(paChar(aString(f_section)), pkeyA, defA, bufA, sizeof(bufA), paChar(aString(f_fileName)));
	if (('' = defString) and (res = 1) and ('0' = bufA[0])) then begin
	  //
	  // check if we got default value or real value
	  defA := '2';
	  //
	  res := GetPrivateProfileStringA(paChar(aString(f_section)), pkeyA, defA, buf2A, sizeof(buf2A), paChar(aString(f_fileName)));
	  if ((1 = res) and ('2' = buf2A[0])) then begin
	    // there is no such key - return default falue
	    result := defValue;
	  end
	  else begin
	    // key exists - return value
	    result := string(bufA);
	  end;
	end
	else
	  setString(result, bufA, res);
	//
      end;
{$ENDIF NO_ANSI_SUPPORT }
      //
    finally
      leave();
    end
  else
    result := '';
end;

// --  --
procedure unaIniFile.setAsString(const value: string);
begin
  // TO DO:
end;

// --  --
procedure unaIniFile.setFileName(const value: wString);
var
  BOM: uint16;
begin
  f_fileName := trimS(value);
  //
  if ('' = f_fileName) then
    f_fileName := getModuleFileNameExt('ini')
  else begin
    //
    if (#1 = f_fileName) then
      f_fileName := getAppDataFolderPath() + '';
  end;
  //
  if (fileExists(f_fileName)) then
  else begin
    //
{$IFNDEF NO_ANSI_SUPPORT }
    if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
      // write UTF-16, little-endian BOM
      BOM := $FEFF;
      writeToFile(f_fileName, @BOM, sizeOf(BOM));
{$IFNDEF NO_ANSI_SUPPORT }
    end;
{$ENDIF NO_ANSI_SUPPORT }
    //
  end;
end;

// --  --
procedure unaIniFile.setStringValue(const key, value: string);
begin
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then begin
{$ENDIF NO_ANSI_SUPPORT }
    // does not support unicode
    WritePrivateProfileStringW(pwChar(wString(f_section)), pwChar(wString(key)), pwChar(wString(value)), pwChar(f_fileName));
{$IFNDEF NO_ANSI_SUPPORT }
  end
  else
    WritePrivateProfileStringA(paChar(aString(f_section)), paChar(aString(key)), paChar(aString(value)), paChar(aString(f_fileName)));
{$ENDIF NO_ANSI_SUPPORT }
end;


{ unaIniMemorySection }

// --  --
procedure unaIniMemorySection.addKeyValue(const key, value: string);
begin
  f_keys.add(key);
  f_values.add(value);
end;

// --  --
procedure unaIniMemorySection.AfterConstruction();
begin
  inherited;
  //
  f_keys := unaStringList.create();
  f_values := unaStringList.create();
end;

// --  --
procedure unaIniMemorySection.BeforeDestruction();
begin
  freeAndNil(f_keys);
  freeAndNil(f_values);
  //
  inherited;
end;

// --  --
constructor unaIniMemorySection.create(const name: string);
begin
  f_name := name;
  //
  inherited create();
end;


{ unaIniMemory }

// --  --
procedure unaIniMemory.BeforeDestruction();
begin
  inherited;
  //
  freeAndNil(f_sections);
end;

// --  --
constructor unaIniMemory.create(memory: pointer; size: unsigned; const section: string; lockTimeout: unsigned);
begin
  f_sections := unaObjectList.create();
  //
  parseMemory(memory, size);
  //
  inherited create(section, lockTimeout);
end;

// --  --
function unaIniMemory.doGetSectionAsText(const sectionName: string): string;
var
  sec: unaIniMemorySection;
  i: int;
begin
  result := '';
  //
  if (enter()) then begin
    try
      //
      sec := getSection(sectionName, false);
      if (nil <> sec) then begin
	//
	if (0 < sec.f_keys.count) then begin
	  //
	  for i := 0 to sec.f_keys.count - 1 do begin
	    //
	    result := result + sec.f_keys.get(i) + '=' + sec.f_values.get(i) + #13#10;
	  end;
	end;
	//
      end;
      //
    finally
      leave('');
    end;
  end
end;

// --  --
function unaIniMemory.doSetSectionAsText(const sectionName, value: string): bool;

  // --  --
  function getNextString(var i: int; const value: string): string;
  var
    s: int;
  begin
    s := i;
    //
    while (i <= length(value)) do begin
      //
      if (aChar(value[i]) in [#13, #10]) then begin
	//
	while (i <= length(value)) do begin
	  //
	  if (not (aChar(value[i]) in [#13, #10])) then
	    break;
	  //
	  inc(i);
	end;
        //
	break;
      end;
      //
      inc(i);
    end;
    //
    if (i > s) then
      result := trimS(copy(string(value), s, i - s))
    else
      result := '';
  end;

var
  sec: unaIniMemorySection;
  i: int;
  str: string;
  p: int;
  nameS, valueS: string;
begin
  result := false;
  //
  if (enter()) then begin
    try
      //
      sec := getSection(sectionName, true);
      //
      if (nil <> sec) then begin
	//
	sec.f_keys.clear();
	sec.f_values.clear();
	//
	i := 1;
	while (i <= length(value)) do begin
	  //
	  str := getNextString(i, value);
	  //
	  if ('' <> str) then begin
	    //
	    p := pos('=', str);
	    if (0 < p) then begin
	      //
	      nameS := copy(str, 1, p - 1);
	      valueS := copy(str, p + 1, maxInt);
	      //
	      sec.f_keys.add(nameS);
	      sec.f_values.add(valueS);
	    end;
	  end;
	end;
      end;
      //
    finally
      leave('');
    end;
  end
end;

// --  --
function unaIniMemory.getAsString(): string;
var
  i, j: unsigned;
  sec: unaIniMemorySection;
begin
  result := '';
  //
  if (0 < f_sections.count) then begin
    //
    for i := 0 to f_sections.count - 1 do begin
      //
      sec := f_sections[i];
      if (nil <> sec) then begin
	//
	result := result + #13#10 + '[' + sec.name + ']';
	//
	if (0 < sec.f_keys.count) then
	  for j := 0 to sec.f_keys.count - 1 do
	    result := result + #13#10 + sec.f_keys.get(j) + '=' + sec.f_values.get(j);
      end;
      //
      result := result + #13#10;
    end;
    //
  end;
end;

// --  --
function unaIniMemory.getSection(const name: string; allowCreation: bool): unaIniMemorySection;
var
  i: unsigned;
  sec: unaIniMemorySection;
begin
  result := nil;
  //
  if (0 < f_sections.count) then begin
    //
    for i := 0 to f_sections.count - 1 do begin
      //
      sec := f_sections[i];
      if (sameString(sec.name, name)) then begin
	//
	result := sec;
	break;
      end;
    end;
    //
  end;
  //
  if ((nil = result) and allowCreation) then begin
    //
    result := unaIniMemorySection.create(upperCase(name));
    f_sections.add(result);
  end;
end;

// --  --
function unaIniMemory.getStringValue(const key, defValue: string): string;
var
  sec: unaIniMemorySection;
  index: int;
begin
  if (enter()) then begin
    try
      //
      sec := getSection(section, false);
      //
      if (nil <> sec) then begin
	//
	index := sec.f_keys.indexOf(key, false);
	if (0 <= index) then
	  result := sec.f_values.get(index)
	else
	  result := defValue;
	//
      end
      else
	result := defValue;
      //
    finally
      leave('');
    end;
  end
  else
    result := '';
end;

// --  --
procedure unaIniMemory.loadFrom(const fileName: wString);
var
  buf: paChar;
  size: int;
  sz: unsigned;
begin
  f_sections.clear();
  //
  size := fileSize(fileName);
  if (0 < size) then begin
    //
    buf := malloc(size);
    try
      //
      sz := size;
      if (0 = readFromFile(fileName, buf, sz)) then
	parseMemory(buf, sz);
      //
    finally
      mrealloc(buf);
    end;
  end;
end;

// --  --
procedure unaIniMemory.parseMemory(memory: paChar; size: unsigned);

  // --  --
  function readString(var offs: unsigned; out value: aString): bool;
  var
    start: unsigned;
    len: unsigned;
  begin
    start := offs;
    //
    while (offs < size) do begin
      //
      if (memory[offs] in [#13, #10]) then begin
	//
	if ((#13 = memory[offs]) and (offs + 1 < size) and (#10 = memory[offs + 1])) then
	  inc(offs);
	//
	inc(offs);
	break;
      end;
      //
      inc(offs);
    end;
    //
    if (offs > start) then begin
      //
      len := offs - start;
      //
      while ((0 < len) and (memory[start + len - 1] in [#13, #10])) do
	dec(len);
      //
      if (0 < len) then begin
	//
	setLength(value, len);
	move(memory[start], value[1], len);
	//
	value := trimS(value, true, false);
      end
      else
        value := '';
      //
      result := true;
    end
    else
      result := false;
    //
  end;

var
  offs: unsigned;
  len: int;
  value: aString;
  name: aString;
  keyValue: string;
  peq: paChar;
  sec: unaIniMemorySection;
begin
  offs := 0;
  sec := nil;
  //
  while (readString(offs, value)) do begin
    //
    len := length(value);
    if (0 < len) then begin
      //
      if ('[' = value[1]) then begin
	//
	if (1 < len) then begin
	  //
	  setLength(name, len - 2);
	  if (2 < len) then
	    move(value[2], name[1], len - 2);
	  //
	  name := trimS(name);
	end
	else
	  name := '';
	//
	sec := getSection(string(name), true);
      end
      else begin
        //
	// add new key
	if (nil = sec) then
	  sec := getSection('', true);
	//
	peq := strScanA(paChar(value), '=');
	if (nil <> peq) then begin
	  //
	  inc(peq);
	  keyValue := string(peq);
	  //
	  len := len - length(keyValue) - 1;
	  if (0 < len) then begin
	    //
	    setLength(name, len);
	    move(value[1], name[1], len);
	  end
	  else
	    name := '';
	  //
	end
	else begin
	  //
	  name := value;
	  keyValue := '';
	end;
	//
	sec.addKeyValue(string(name), keyValue);
      end;
    end;
    //
  end;
end;

// --  --
procedure unaIniMemory.saveTo(const fileName: wString);
begin
  writeToFile(fileName, aString(getAsString()));
end;

// --  --
procedure unaIniMemory.setAsString(const value: string);
begin
  f_sections.clear();
  //
  if ('' <> trimS(value)) then
    parseMemory(@aString(value)[1], length(value));
end;

// --  --
procedure unaIniMemory.setStringValue(const key, value: string);
var
  sec: unaIniMemorySection;
  index: int;
begin
  if (enter()) then begin
    try
      //
      sec := getSection(section, true);
      //
      if (nil <> sec) then begin
	//
	index := sec.f_keys.indexOf(key, false);
	if (0 <= index) then
	  sec.f_values.setItem(index, value)
	else
	  sec.addKeyValue(key, value);
	//
      end;
      //
    finally
      leave('');
    end;
  end;
end;


{ unaAbstractStream }

// --  --
procedure unaAbstractStream.AfterConstruction();
begin
  inherited;
  //
{$IFDEF DEBUG}
  f_title := title;
{$ENDIF}
  //
  f_gate := unaInProcessGate.create({$IFDEF DEBUG}self._classID + '(' + title + '.f_gate)'{$ENDIF});
  f_dataEvent := unaEvent.create();
end;

// --  --
function unaAbstractStream.clear(): unaAbstractStream;
begin
  // BCB stub
  result := clear2();
end;

// --  --
function unaAbstractStream.clear2(): unaAbstractStream;
begin
  result := self;
end;

// --  --
class function unaAbstractStream.copyStream(source, dest: unaAbstractStream): int;
var
  buf: pointer;
  bufSize: int;
  size: int;
begin
  result := 0;
  bufSize := $10000;
  buf := malloc(bufSize);
  try
    repeat
      //
      size := source.read(buf, bufSize, true);
      if (0 < size) then begin
	//
	dest.write(buf, size);
	inc(result, size);
      end
      else
	break;
      //
    until (false);
    //
  finally
    mrealloc(buf);
  end;
end;

// --  --
constructor unaAbstractStream.create(lockTimeout: unsigned{$IFDEF DEBUG }; const title: string{$ENDIF DEBUG });
begin
  inherited create();
  //
  f_pos := 0;
  f_summarySize := 0;
  f_lockTimeout := lockTimeout;
  //
  {$IFDEF DEBUG }
  f_title := title;
  {$ENDIF DEBUG }
end;

// --  --
function unaAbstractStream.remove2(size: int): int;
begin
  // not all streams do support deleteion
  result := 0;
end;

// --  --
destructor unaAbstractStream.Destroy();
begin
  inherited;
  //
  freeAndNil(f_gate);
  freeAndNil(f_dataEvent);
end;

// --  --
function unaAbstractStream.enter(timeout: unsigned{$IFDEF DEBUG }; const masterName: string{$ENDIF DEBUG }): bool;
{$IFDEF UNA_GATE_DEBUG }
var
  id: unsigned;
  lc: unsigned;
  rc: unsigned;
{$ENDIF}
begin
{$IFDEF UNA_GATE_DEBUG }
  id := f_gate.getOwningThread();
  lc := f_gate.getTryLockCount();
  rc := f_gate.getRecursionLockCount();
  //
  infoMessage('about to ENTER: #' + int2str(id) + '|' + int2str(lc) + '|' + int2str(rc));
{$ENDIF UNA_GATE_DEBUG }
  result := f_gate.enter(choice(INFINITE = timeout, f_lockTimeout, timeout){$IFDEF DEBUG}, 'by ' + self._classID + ' of ' + masterName{$ENDIF});
{$IFDEF UNA_GATE_DEBUG }
  if (result) then
    infoMessage('ENTER: OK #' + int2str(id) + '|' + int2str(lc) + '|' + int2str(rc) + '/' + int2str(f_gate.getOwningThread()) + '|' + int2str(f_gate.getTryLockCount()) + '|' + int2str(f_gate.getRecursionLockCount()))
  else
    infoMessage('ENTER: er #' + int2str(id) + '|' + int2str(lc) + '|' + int2str(rc) + '/' + int2str(f_gate.getOwningThread()) + '|' + int2str(f_gate.getTryLockCount()) + '|' + int2str(f_gate.getRecursionLockCount()));
{$ENDIF UNA_GATE_DEBUG }
end;

// --  --
function unaAbstractStream.getAvailableSize(): int;
begin
  // BCB stub
  result := getAvailableSize2();
end;

// --  --
function unaAbstractStream.getAvailableSize2(): int;
begin
  // this should work for most cases
  if (0 < f_summarySize) then
    result := 1 + f_summarySize - f_pos
  else
    result := 0;
end;

// --  --
function unaAbstractStream.getIsEmpty(): bool;
begin
  result := (1 > getSize());
end;

// --  --
function unaAbstractStream.getPosition(): int;
begin
  result := f_pos;
end;

// --  --
function unaAbstractStream.getSize(): int;
begin
  // BCB stub
  result := getSize2();
end;

// --  --
function unaAbstractStream.getSize2(): int;
begin
  // this should work for most cases
  result := f_summarySize;
end;

// --  --
procedure unaAbstractStream.leave();
begin
  f_gate.leave();
end;

// --  --
function unaAbstractStream.read(def: byte; remove: bool): byte;
begin
  if (read(@result, sizeOf(result), remove) <> sizeOf(result)) then
    result := def;
end;

// --  --
function unaAbstractStream.read(def: boolean; remove: bool): bool;
begin
  if (read(@result, sizeOf(result), remove) <> sizeOf(result)) then
    result := def;
end;

// --  --
function unaAbstractStream.read(def: word; remove: bool): word;
begin
  if (read(@result, sizeOf(result), remove) <> sizeOf(result)) then
    result := def;
end;

// --  --
function unaAbstractStream.read(def: int; remove: bool): int;
begin
  if (read(@result, sizeOf(result), remove) <> sizeOf(result)) then
    result := def;
end;

// --  --
function unaAbstractStream.read(const def: aString; remove: bool): aString;
var
  len: int;
begin
  len := getAvailableSize();
  if (0 < len) then begin
    //
    setLength(result, len);
    if (read(@result[1], len, remove) <> len) then
      result := def;
  end
  else
    result := def;
end;

// --  --
function unaAbstractStream.read(def: unsigned; remove: bool): unsigned;
begin
  if (read(@result, sizeOf(result), remove) <> sizeOf(result)) then
    result := def;
end;

function unaAbstractStream.read(buf: pointer; size: int; remove: bool = true): int;
begin
  // BCB stub
  result := read2(buf, size, remove);
  //
  if (1 > f_summarySize) then
    f_dataEvent.setState(false);	// mark we have no data
end;

// --  --
function unaAbstractStream.readFrom(source: unaAbstractStream): int;
begin
  result := copyStream(source, self);
end;

// -- --
function unaAbstractStream.readFrom(const fileName: wString; offset: int): int;
const
  buf_size = 100000;
var
  f: tHandle;
  size: int;
  buf: pointer;
  cur_size: DWORD;
begin
  result := 0;
  //
  if (fileExists(fileName)) then begin
    //
{$IFNDEF NO_ANSI_SUPPORT }
    if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
      f := CreateFileW(pwChar(fileName), GENERIC_READ, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
{$IFNDEF NO_ANSI_SUPPORT }
    else
      f := CreateFileA(paChar(aString(fileName)), GENERIC_READ, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
{$ENDIF NO_ANSI_SUPPORT }
    ;
    //
    if (INVALID_HANDLE_VALUE <> f) then begin
      //
      try
	// read file content
	size := SetFilePointer(f, 0, nil, FILE_END);
	SetFilePointer(f, offset, nil, FILE_BEGIN);
	//
	if (offset < size) then
	  dec(size, offset)
	else
	  size := 0;
	//
	if (0 < size) then begin
	  //
	  buf := malloc(buf_size);
	  try
	    //
	    while (result < size) do begin
	      //
	      cur_size := size - result;
	      if (cur_size > buf_size) then
		cur_size := buf_size;
	      //
	      if (ReadFile(f, buf, cur_size, @cur_size, nil) and (0 < cur_size)) then begin
		//
		write(buf, cur_size);
		inc(result, cur_size);
	      end
	      else
		break;
	      //
	    end;
	    //
	  finally
	    mrealloc(buf);
	  end;
	end;
      //
      finally
	CloseHandle(f);
      end;	
    end;
  end;
end;

// --  --
function unaAbstractStream.remove(size: int): int;
begin
  // BCB stub
  result := remove2(size);
end;

// --  --
function unaAbstractStream.seekD(delta: int): int;
begin
  if (enter()) then begin
    try
      if ((0 > delta) and (abs(delta) >= int(f_pos))) then
	f_pos := 0
      else begin
	//
	inc(f_pos, delta);
	if (f_summarySize < f_pos) then
	  f_pos := f_summarySize;
	//
      end;
    finally
      leave();
    end;
  end;
  //
  result := f_pos;
end;

// --  --
function unaAbstractStream.seek(position: int; fromBeggining: bool): int;
begin
  if (enter()) then begin
    try
      if (fromBeggining) then
	f_pos := min(f_summarySize, position)
      else
	f_pos := max(0, f_summarySize - position);
    finally
      leave();
    end;
  end;
  //
  result := f_pos;
end;

// --  --
function unaAbstractStream.waitForData(timeout: unsigned): bool;
begin
  if ((0 >= f_summarySize) and (0 < timeout)) then
    f_dataEvent.waitFor(timeout);
  //
  result := (0 < f_summarySize);
end;

// --  --
function unaAbstractStream.write(value: boolean): int;
begin
  result := write(@value, sizeOf(value));
end;

// --  --
function unaAbstractStream.write(value: byte): int;
begin
  result := write(@value, sizeOf(value));
end;

// --  --
function unaAbstractStream.write(value: int): int;
begin
  result := write(@value, sizeOf(value));
end;

// --  --
function unaAbstractStream.write(value: unsigned): int;
begin
  result := write(@value, sizeOf(value));
end;

function unaAbstractStream.write(value: word): int;
begin
  result := write(@value, sizeOf(value));
end;

// --  --
function unaAbstractStream.write(const value: aString): int;
begin
  if ('' <> value) then
    result := write(@value[1], length(value))
  else
    result := 0;
end;

// --  --
function unaAbstractStream.writeTo(const fileName: wString; append: bool; size: int): int;
const
  buf_size = 10000;
var
  f: tHandle;
  flags: unsigned;
  sizeToWrite: int;
  buf: pointer;
  cur_size: DWORD;
begin
  result := 0;
  if ('' <> fileName) then begin
    //
    if (fileExists(fileName)) then begin
      //
      if (append) then
	flags := OPEN_EXISTING
      else
	flags := TRUNCATE_EXISTING;
      //
    end
    else
      flags := CREATE_NEW;
    //
{$IFNDEF NO_ANSI_SUPPORT }
    if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
      f := CreateFileW(pwChar(fileName), GENERIC_WRITE, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, flags, FILE_ATTRIBUTE_NORMAL, 0)
{$IFNDEF NO_ANSI_SUPPORT }
    else
      f := CreateFileA(paChar(aString(fileName)), GENERIC_WRITE, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, flags, FILE_ATTRIBUTE_NORMAL, 0);
{$ENDIF NO_ANSI_SUPPORT }
    ;
    //
    if (INVALID_HANDLE_VALUE <> f) then begin

      // write file content
      if (0 >= size) then
	sizeToWrite := getSize()
      else
	sizeToWrite := min(size, getSize());
      //
      if (0 < sizeToWrite) then begin
	//
	if (append) then
	  SetFilePointer(f, 0, nil, FILE_END);
	//
	buf := malloc(buf_size);
	try
	  while (result < sizeToWrite) do begin
	    //
	    cur_size := sizeToWrite - result;
	    if (cur_size > buf_size) then
	      cur_size := buf_size;
	    //
	    cur_size := read(buf, int(cur_size));
	    //
	    if (WriteFile(f, buf, cur_size, @cur_size, nil)) then
	      inc(result, cur_size)
	    else
	      break;
	    //
	  end;
	finally
	  mrealloc(buf);
	end;
      end;
      //
      CloseHandle(f);
    end;
  end;
end;

// --  --
function unaAbstractStream.write(buf: pointer; size: int): int;
begin
  if ((1 > maxSize) or (getSize() + size < maxSize)) then
    // BCB stub
    result := write2(buf, size)
  else
    result := 0;
end;

// --  --
function unaAbstractStream.write2(buf: pointer; size: int): int;
begin
  if (0 < size) then
    f_dataEvent.setState();	// signal we have some data now
  //
  result := size;
end;

// --  --
function unaAbstractStream.writeTo(dest: unaAbstractStream): int;
begin
  result := copyStream(self, dest);
end;


{ unaStreamChunk }

// --  --
constructor unaStreamChunk.create(buf: pointer; size: int);
begin
  inherited create();
  //
  f_buf := nil;
  f_bufSize := 0;
  newData(buf, size);
end;

// --  --
destructor unaStreamChunk.Destroy();
begin
  mrealloc(f_buf);
  //
  inherited;
end;

// --  --
function unaStreamChunk.getSize(): int;
begin
  result := f_dataSize - f_offset;
end;

// --  --
procedure unaStreamChunk.newData(buf: pointer; size: int);
begin
  if (f_bufSize < size) then begin
    //
    mrealloc(f_buf, size);
    f_bufSize := size;
  end;
  //
  if (nil <> buf) then
    move(buf^, f_buf^, size)
  else
    size := 0;
  //
  f_dataSize := size;
  f_offset := 0;
end;

// --  --
function unaStreamChunk.read(buf: pointer; size: int; remove: bool): int;
begin
  result := min(size, getSize());
  //
  if (0 < result) then begin
    //
    move(paChar(f_buf)[f_offset], buf^, result);
    //
    if (remove) then
      inc(f_offset, result);
  end;
end;


{ unaMemoryStream }

// --  --
procedure unaMemoryStream.AfterConstruction();
begin
  f_chunks := unaObjectList.create(false);
  f_chunks.singleThreaded := true;
  //
  f_emptyChunks := unaObjectList.create(false);
  f_emptyChunks.singleThreaded := true;
  //
  f_maxCacheSize := 10;
  f_isValid := true;
  //
  inherited;
end;

// --  --
function unaMemoryStream.clear2(): unaAbstractStream;
begin
  if (enter()) then begin
    try
      f_chunks.autoFree := true;
      f_emptyChunks.autoFree := true;
      //
      f_chunks.clear();
      f_emptyChunks.clear();
      //
      f_chunks.autoFree := false;
      f_emptyChunks.autoFree := false;
      //
      f_summarySize := 0;
    finally
      leave();
    end;
  end;
  //
  result := inherited clear2();
end;

// --  --
function unaMemoryStream.remove2(size: int): int;
begin
  // not supported
  result := 0;
end;

// --  --
destructor unaMemoryStream.Destroy();
begin
  clear();
  //
  inherited;
  //
  freeAndNil(f_emptyChunks);
  freeAndNil(f_chunks);
end;

// --  --
function unaMemoryStream.getAvailableSize2(): int;
begin
  // seeking is not supported
  result := getSize();
end;

// --  --
function unaMemoryStream.getCrc32(): unsigned;
var
  buf: pointer;
  size: unsigned;
begin
  if (enter()) then begin
    try
      size := getSize();
      buf := malloc(size);
      try
	read(buf, size, false);
	result := crc32(buf, size);
      finally
	mrealloc(buf);
      end;
    finally
      leave();
    end;
  end
  else begin
    result := 0;
  end;
end;

// --  --
function unaMemoryStream.getFirstChunkSize(): int;
begin
  if (enter()) then begin
    try
      if (0 < f_chunks.count) then
	result := unaStreamChunk(f_chunks[0]).getSize()
      else
	result := 0;
      //
    finally
      leave();
    end;
  end
  else begin
    //
    result := 0;
  end;
end;

// --  --
function unaMemoryStream.getPosition(): int;
begin
  // not supported
  result := 0;
end;

// --  --
function unaMemoryStream.read2(buf: pointer; size: int; remove: bool): int;
var
  sub: unsigned;
  sub2: unsigned;
  chunk: unaStreamChunk;
  chunk2: unaStreamChunk;
  offset: unsigned;
  i: int;
  j: int;
begin
  result := 0;
  //
  if (0 < size) then begin
    //
    if (enter()) then begin
      try
	offset := 0;
	sub := min(size, getSize());
	if ((nil <> buf) and (0 < sub)) then begin
	  //
	  i := 0;
	  while ((0 < sub) and (i < f_chunks.count)) do begin
	    //
	    chunk := f_chunks[i];
	    sub2 := min(sub, chunk.getSize());
	    if (0 < sub2) then begin
	      //
	      chunk.read(@paChar(buf)[offset], sub2, remove);
	      inc(offset, sub2);
	      dec(sub, sub2);
	    end;
	    //
	    if (remove and (0 >= chunk.getSize())) then begin
	      //
	      if (f_emptyChunks.count < int(f_maxCacheSize)) then
		//
		f_emptyChunks.add(chunk)
	      else begin
		//
		j := 0;
		while (j < f_emptyChunks.Count) do begin
		  //
		  chunk2 := f_emptyChunks[j];
		  if (chunk2.f_bufSize < chunk.f_bufSize) then begin
		    //
		    f_emptyChunks[j] := chunk;
		    chunk := chunk2;
		    break;
		  end;
		  //
		  inc(j)
		end;
		//
		freeAndNil(chunk);
	      end;
	      //
	      f_chunks.removeByIndex(i)
	    end
	    else
	      inc(i);
	  end;
	end;
	//
	result := offset;
	//
	if (remove) then
	  dec(f_summarySize, result);
	//
      finally
	leave();
      end;
    end;
  end;
end;

// --  --
function unaMemoryStream.seek(position: int; fromBeggining: bool): int;
begin
  // not supported
  result := 0;
end;

// --  --
function unaMemoryStream.seekD(delta: int): int;
begin
  // not supported
  result := 0;
end;

// --  --
function unaMemoryStream.write2(buf: pointer; size: int): int;
var
  i: int;
  chunk: unaStreamChunk;
begin
  result := 0;
  //
  if ((nil <> buf) and (0 < size)) then begin
    //
    if (enter()) then begin
      try
	if (0 < f_emptyChunks.count) then begin
	  //
	  i := 0;
	  repeat
	    //
	    inc(i);
	    chunk := f_emptyChunks[i - 1];
	    if (chunk.f_bufSize >= size) then
	      break;
	    //
	  until (i >= f_emptyChunks.count);
	  //
	  f_emptyChunks.removeByIndex(i - 1);
	  chunk.newData(buf, size);
	end
	else
	  chunk := unaStreamChunk.create(buf, size);
	//
	f_chunks.add(chunk);
	inc(f_summarySize, size);
	//
	result := size;
      finally
	leave();
      end;
    end;
  end;
  //
  inherited write2(buf, size);
end;


{ unaMemoryData }

// --  ---
procedure unaMemoryData.BeforeDestruction();
begin
  mrealloc(f_data);
  f_summarySize := 0;
  //
  inherited;
end;

// --  ---
constructor unaMemoryData.createData(data: pointer; size: int);
begin
  inherited create();
  //
  if ((nil <> data) and (0 < size)) then begin
    //
    f_data := malloc(size, data);
    f_summarySize := size;
  end
  else begin
    //
    f_summarySize := 0;
    f_data := nil;
  end;
  //
  f_isValid := true;
end;

// --  ---
function unaMemoryData.remove2(size: int): int;
var
  msize: int;
begin
  if (enter()) then begin
    try
      result := min(getAvailableSize(), size);
      if (0 < result) then begin
	//
	msize := (f_summarySize - (f_pos + result));
	if (0 < msize) then
	  move(f_data[f_pos + size], f_data[f_pos], msize);
	//
	dec(f_summarySize, result);
	mrealloc(f_data, f_summarySize);
      end;
    finally
      leave();
    end;
  end
  else begin
    result := 0;
  end;
end;

// --  ---
function unaMemoryData.read2(buf: pointer; size: int; remove: bool): int;
begin
  if (enter()) then begin
    try
      result := min(getAvailableSize(), size);
      if (0 < result) then
	move(f_data[f_pos], buf^, result);
      //
      if (remove) then
	self.remove(size);
    finally
      leave();
    end;
  end
  else begin
    result := 0;
  end;
end;

// --  ---
function unaMemoryData.write2(buf: pointer; size: int): int;
var
  msize: int;
begin
  result := size;
  //
  if (enter()) then begin
    try
      msize := getAvailableSize();
      if (size > msize) then begin
	//
	mrealloc(f_data, f_summarySize + (size - msize));
	inc(f_summarySize, size - msize);
      end;
      //
      move(buf^, f_data[f_pos], size);
    finally
      leave();
    end;
  end;
  //
  inherited write2(data, size);
end;


{ unaFileStream }

// --  --
procedure unaFileStream.AfterConstruction();
begin
  inherited;
  //
  f_handle := INVALID_HANDLE_VALUE;
  //
  if ('' <> f_fileName) then
    initStream(f_fileName, f_access, f_shareMode, f_loop, f_fileFlags);
end;

function unaFileStream.clear2(): unaAbstractStream;
begin
  if (enter()) then begin
    try
      unaUtils.fileTruncate(f_handle);
      f_summarySize := 0;
    finally
      leave();
    end;
  end;
  //
  result := inherited clear2();
end;

// --  --
procedure unaFileStream.close();
begin
  CloseHandle(f_handle);
  f_handle := INVALID_HANDLE_VALUE;
end;

// --  --
constructor unaFileStream.createStream(const fileName: wString; access: unsigned; shareMode: unsigned; loop: bool; fileFlags: unsigned);
begin
  inherited create();
  //
  f_fileName := fileName;
  f_access := access;
  f_shareMode := shareMode;
  f_loop := loop;
  f_fileFlags := fileFlags;
end;

// --  --
destructor unaFileStream.Destroy();
begin
  close();
  //
  inherited;
end;

// --  --
function unaFileStream.getAvailableSize2(): int;
begin
  if (f_loop) then
    result := f_summarySize
  else
    result := getSize() - getPosition();
end;

// --  --
function unaFileStream.getPosition(): int;
begin
  result := fileSeek(f_handle, 0, FILE_CURRENT);
end;

// --  --
function unaFileStream.getSize2(): int;
begin
  result := fileSize(f_handle);
  f_summarySize := result;
end;

// --  --
function unaFileStream.initStream(const fileName: wString; access: unsigned; shareMode: unsigned; loop: bool; fileFlags: unsigned): bool;
var
  flags: unsigned;
begin
  if (enter()) then begin
    try
      //
      close();
      //
      f_fileName := fileName;
      f_loop := loop;
      if (fileExists(fileName)) then
	flags := OPEN_EXISTING
      else
	flags := CREATE_NEW;
      //
{$IFNDEF NO_ANSI_SUPPORT }
      if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	f_handle := CreateFileW(pwChar(fileName), access, shareMode, nil, flags, fileFlags, 0)
{$IFNDEF NO_ANSI_SUPPORT }
      else
	f_handle := CreateFileA(paChar(aString(fileName)), access, shareMode, nil, flags, fileFlags, 0);
{$ENDIF NO_ANSI_SUPPORT }
      ;
      //
      result := (INVALID_HANDLE_VALUE <> f_handle);
      //
      if (result) then begin
	//
	seek(0, true);
	f_summarySize := fileSize(f_handle);
      end;
      //
      f_isValid := result;
    finally
      leave();
    end;
  end
  else begin
    result := false;
  end;
end;

// --  --
function unaFileStream.read2(buf: pointer; size: int; remove: bool): int;
var
  res: int;
  sz: unsigned;
begin
  result := 0;
  //
  if (isValid) then begin
    if (enter()) then begin
      try
	sz := size;
	res := readFromFile(f_handle, buf, sz);
	if ((-4 = res) or (0 <= res)) then
	  result := sz
	else
	  result := 0;
	//
	//
	if (f_loop and (result < size)) then begin
	  //
	  // loop the file from beginning
	  seek(0, true);
	  result := result + read(@pArray(buf)[result], size - result, remove{, false});
	end
	else
	  //
	  if (remove) then
	    inc(f_fileOffset, result)
	  else
	    seekD(0 - int(result));
      finally
	leave();
      end;
    end;
  end;
end;

// --  --
function unaFileStream.seek(position: int; fromBeggining: bool): int;
begin
  result := fileSeek(f_handle, position, choice(fromBeggining, unsigned(FILE_BEGIN), FILE_END));
  f_fileOffset := result;
end;

// --  --
function unaFileStream.seekD(delta: int): int;
begin
  result := getPosition();
  //
  if (delta < 0) then begin
    //
    if (result < -delta) then
      result := 0
    else
      result := result + delta
  end
  else
    result := result + delta;
  //
  result := seek(result, true);
end;

// --  --
function unaFileStream.write2(buf: pointer; size: int): int;
var
  res: int;
begin
  result := 0;
  //
  if (isValid) then begin
    if (enter()) then begin
      try
	res := writeToFile(f_handle, buf, size);
	if (0 > res) then
	  result := 0
	else
	  result := size;
	//
	getSize();
      finally
	leave();
      end;
    end;
  end;
  //
  inherited write2(buf, size);
end;

{ unaResourceStream }

// --  --
procedure unaResourceStream.AfterConstruction();
begin
  inherited;
  //
  if (enter()) then begin
    try
      if (0 = find(f_name, f_resType, f_instance)) then
	lock();
      //	
    finally
      leave();
    end;
  end;
end;

// --  --
procedure unaResourceStream.BeforeDestruction();
begin
  unlock();
  //
  inherited;
end;

// --  --
constructor unaResourceStream.createRes(const name: wString; resType: pwChar; instance: hModule);
begin
  inherited create();
  //
  f_name := name;
  f_resType := resType;
  f_instance := instance;
end;

// --  --
function unaResourceStream.find(const name: wString; resType: pwChar; instance: hModule): int;
begin
  if (enter()) then begin
    try
      //
{$IFNDEF NO_ANSI_SUPPORT }
      if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	f_resource := FindResourceW(instance, pwChar(name), resType)
{$IFNDEF NO_ANSI_SUPPORT }
      else
	f_resource := FindResourceA(instance, paChar(aString(name)), paChar(resType));
{$ENDIF NO_ANSI_SUPPORT }
      ;
      //
      if (0 = f_resource) then
        //
	result := GetLastError()
      else
	result := 0;
      //
    finally
      leave();
    end;
  end
  else begin
    result := -1;
  end;
end;

// --  --
function unaResourceStream.lock(): int;
begin
  result := -1;
  //
  if (enter()) then begin
    try
      if (0 <> f_resource) then begin
	//
	unlock();
	//
	f_global := LoadResource(f_instance, f_resource);
	if (0 <> f_global) then begin
	  //
	  f_summarySize := SizeofResource(f_instance, f_resource);
	  f_data := LockResource(f_global);
	  f_isValid := true;
	  result := 0;
	end;
	//
	f_pos := 0;
      end;
    finally
      leave();
    end;
  end;
end;

// --  --
function unaResourceStream.read2(buf: pointer; size: int; remove: bool): int;
begin
  if (enter()) then begin
    try
      if (isValid) then begin
	//
	result := min(f_summarySize - f_pos, size);
	move(paChar(data)[f_pos], buf^, result);
	seekD(int(result));
      end
      else
	result := 0;
      //	
    finally
      leave();
    end;
  end
  else begin
    result := 0;
  end;
end;

// --  --
procedure unaResourceStream.unlock();
begin
  if (enter()) then begin
    try
      //
      f_data := nil;
      f_summarySize := 0;
      f_pos := 0;
      //
      if (0 <> f_global) then begin
        //
	UnlockResource(f_global);
	FreeResource(f_global);
	//
	f_global := 0;
      end;
    finally
      leave();
    end;
  end;
end;

// --  --
function unaResourceStream.write2(buf: pointer; size: int): int;
begin
  {$IFDEF LOG_UNACLASSES_INFOS }
  logMessage(self._classID + '.write2() - method not supported.');
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
  result := 0;
end;

{ unaMappedMemory }

// --  --
procedure unaMappedMemory.AfterConstruction();
begin
  inherited;
  //
  if (f_doOpen) then
    open(f_access);
end;

// --  --
procedure unaMappedMemory.BeforeDestruction();
begin
  inherited;
  //
  close();
  //
  freeAndNil(f_openViews);
end;

// --  --
procedure unaMappedMemory.close();
begin
  // BCB stub
  close2();
end;

// --  --
procedure unaMappedMemory.close2();
begin
  if (0 <> f_handle) then begin
    //
    while (0 < f_openViews.count) do
      unmapView(f_openViews[0]);	// will also remove this view from f_openViews list
    //
    CloseHandle(f_handle);
    f_handle := 0;
  end;
end;

// --  --
constructor unaMappedMemory.create(const name: wString; size64: int64; access: DWORD; doOpen: bool; canCreate: bool);
var
  sysInfo: SYSTEM_INFO;
begin
  inherited create();
  //
  f_canCreate := canCreate;
  f_name := name;
  f_size64 := size64;
  f_fileHandle := INVALID_HANDLE_VALUE;
  f_doOpen := doOpen;
  f_access := access;
  //
  GetSystemInfo(sysInfo);
  f_allocGran := sysInfo.dwAllocationGranularity;
  //
  f_openViews := unaList.create();
end;

// --  --
procedure unaMappedMemory.doSetNewSize(newValue: int64);
begin
  close();
  //
  f_size64 := newValue;
  //
  open(f_access);
end;

// --  --
function unaMappedMemory.flush(): bool;
var
  i: unsigned;
begin
  if (lockNonEmptyList(f_openViews)) then try
    //
    for i := 0 to f_openViews.count - 1 do
      FlushViewOfFile(f_openViews[i], 0);
    //
  finally
    f_openViews.unlock();
  end;
  //
  result := true;
end;

// --  --
function unaMappedMemory.mapHeader(size: int): pointer;
var
  so: int;
begin
  if (0 > size) then
    size := allocGran;
  //
  if ((nil <> f_header) and (f_headerSize >= size)) then
    result := f_header
  else begin
    //
    if (nil <> f_header) then
      unmapView(f_header);
    //
    result := mapView(0, size, so);
    if (0 <> so) then
      result := nil;	// should not be here
    //
    f_header := result;
    f_headerSize := size;
  end;
end;

// --  --
function unaMappedMemory.mapView(offset: int64; reqSize: unsigned; out subOfs: int): pointer;
var
  gofs: int64;
begin
  if (offset + reqSize <= size64) then begin
    //
    gofs := (offset div allocGran) * allocGran;
    inc(reqSize, offset - gofs);
    //
    result := MapViewOfFile(f_handle, f_mapFlags, gofs shr 32, gofs and $FFFFFFFF, reqSize);
    if (nil <> result) then
      f_openViews.add(result);
    //
    subOfs := (offset - gofs);
  end
  else
    result := nil;
end;

// --  --
function unaMappedMemory.mapViewAll(): pointer;
var
  sb: int;
begin
  result := mapView(0, size64, sb);
end;

// --  --
function unaMappedMemory.open(access: DWORD): bool;
begin
  // BCB stub
  result := open2(access);
end;

// --  --
function unaMappedMemory.open2(access: DWORD): bool;
begin
  if (0 = f_handle) then begin
    //
    // 0. convert access flags
    f_mapFlags := 0;
    if (0 <> (access and PAGE_READONLY)) then
      f_mapFlags := f_mapFlags or FILE_MAP_READ;
    if (0 <> (access and PAGE_READWRITE)) then
      f_mapFlags := f_mapFlags or FILE_MAP_WRITE;
    if (0 <> (access and PAGE_WRITECOPY)) then
      f_mapFlags := f_mapFlags or FILE_MAP_COPY;
    //
    // 1. try to open a mapping with given name
{$IFNDEF NO_ANSI_SUPPORT }
    if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
      f_handle := OpenFileMappingW(f_mapFlags, FALSE, pwChar(f_name))
{$IFNDEF NO_ANSI_SUPPORT }
    else
      f_handle := OpenFileMappingA(f_mapFlags, FALSE, paChar(aString(f_name)));
{$ENDIF NO_ANSI_SUPPORT }
    ;
    //
    if (0 = f_handle) then begin
      //
      // 2. try to create
      if (f_canCreate) then begin
	//
{$IFNDEF NO_ANSI_SUPPORT }
	if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	  f_handle := CreateFileMappingW(f_fileHandle, nil, access + SEC_COMMIT, f_size64 shr 32, f_size64 and $FFFFFFFF, pwChar(f_name))
{$IFNDEF NO_ANSI_SUPPORT }
	else
	  f_handle := CreateFileMappingA(f_fileHandle, nil, access + SEC_COMMIT, f_size64 shr 32, f_size64 and $FFFFFFFF, paChar(aString(f_name)));
{$ENDIF NO_ANSI_SUPPORT }
        ;
	//
      end;
    end;
    //
    result := (0 <> f_handle);
  end
  else
    result := false;
end;

// --  --
function unaMappedMemory.read(offs: int64; buf: pointer; sz: unsigned): unsigned;
var
  subOfs: int;
  view: pArray;
begin
  if (offs < size64) then
    result := min(sz, size64 - offs)
  else
    result := 0;
  //    
  if (0 < result) then begin
    //
    view := mapView(offs, result, subOfs);
    if (nil <> view) then try
      //
      move(view[subOfs], buf^, result);
    finally
      unmapView(view);
    end;
  end;
end;

// --  --
procedure unaMappedMemory.setSize(value: int64);
begin
  if (f_size64 <> value) then
    doSetNewSize(value);
end;

// --  --
function unaMappedMemory.unmapView(baseAddr: pointer): bool;
var
  index: int;
begin
  result := UnmapViewOfFile(baseAddr);
  if (result) then begin
    //
    index := f_openViews.indexOf(baseAddr);
    if (0 <= index) then
      f_openViews.removeByIndex(index);
  end;
end;

// --  --
function unaMappedMemory.write(offs: int64; buf: pointer; sz: unsigned): unsigned;
var
  subOfs: int;
  view: pArray;
begin
  result := min(sz, size64 - offs);
  if (0 < result) then begin
    //
    view := mapView(offs, result, subOfs);
    if (nil <> view) then try
      //
      move(buf^, view[subOfs], result);
    finally
      unmapView(view);
    end;
  end;
end;


{ unaMappedFile }

// --  --
procedure unaMappedFile.close2();
begin
  inherited;
  //
  CloseHandle(f_fileHandle);
  f_fileHandle := INVALID_HANDLE_VALUE;
end;

// --  --
constructor unaMappedFile.create(const fileName: wString; access: DWORD; doOpen: bool; size: int);
begin
  f_fileName := fileName;
  //
  inherited create(wString(base64encode(UTF162UTF8(fileName))), size, access, doOpen);
end;

// --  --
function unaMappedFile.ensureSize(value: int64): bool;
begin
  if (size64 < value) then
    size64 := value;
  //
  result := (0 <> f_handle);
end;

// --  --
function unaMappedFile.open2(access: DWORD): bool;
var
  buf: array[0..31] of aChar;
  flags: unsigned;
  canWrite: bool;
begin
  if ('' <> trimS(f_fileName)) then begin
    //
    // check file size
    canWrite := (0 = (access and PAGE_READONLY));
    if (fileExists(f_fileName) or canWrite) then begin
      //
      if (32 > size64) then begin
	//
	if (0 > fileSize(f_fileName)) then
	  f_size64 := 0
	else
	  f_size64 := fileSize(f_fileName);
      end;
      //
      // make sure file size has at least 32 bytes
      if ((32 > f_size64) and canWrite) then begin
	//
	forceDirectories(extractFilePath(f_fileName));
	//
	//buf := padChar(#0, 32 - f_size);
	fillChar(buf, sizeOf(buf), #0);	// avoid writing stack values into file
	writeToFile(f_fileName, pointer(@buf), sizeOf(buf));
	//
	f_size64 := fileSize(f_fileName);
      end;
    end
    else
      f_size64 := 0;
    //
    // open the file
    if (32 > f_size64) then begin
      //
      result := false;	   // do not map this file;
      f_size64 := 0;
    end
    else begin
      //
      flags := 0;
      if (0 <> (access and PAGE_READONLY)) then
	flags := flags or GENERIC_READ;
      if (0 <> (access and PAGE_READWRITE)) then
	flags := flags or GENERIC_WRITE or GENERIC_READ;
      if (0 <> (access and PAGE_WRITECOPY)) then
	flags := flags or GENERIC_WRITE or GENERIC_READ;
      //
{$IFNDEF NO_ANSI_SUPPORT }
      if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
	f_fileHandle := CreateFileW(pwChar(f_fileName), flags, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, choice(fileExists(f_fileName), unsigned(OPEN_EXISTING), CREATE_NEW), FILE_ATTRIBUTE_NORMAL, 0)
{$IFNDEF NO_ANSI_SUPPORT }
      else
	f_fileHandle := CreateFileA(paChar(aString(f_fileName)), flags, FILE_SHARE_READ + FILE_SHARE_WRITE, nil, choice(fileExists(f_fileName), unsigned(OPEN_EXISTING), CREATE_NEW), FILE_ATTRIBUTE_NORMAL, 0);
{$ENDIF NO_ANSI_SUPPORT }
      ;
      //
      result := inherited open2(access);
    end;
  end
  else begin
    // open memory mapping, since file name is empty
    close();
    result := inherited open2(access);
  end;
end;

// --  --
function unaMappedFile.openFile(const fileName: wString; access: DWORD; size: int): bool;
begin
  close();
  //
  f_fileName := fileName;
  //
  result := open(access);
end;

{ unaConsoleApp }

// --  --
procedure unaConsoleApp.AfterConstruction();
begin
  inherited;
  //
  f_ok := doInit();
end;

// --  --
constructor unaConsoleApp.create(const caption: wString; icon: hIcon; textAttribute: unsigned);
begin
  inherited create();
  //
  f_outHandle := GetStdHandle(DWORD(STD_OUTPUT_HANDLE));
  f_inHandle := GetStdHandle(DWORD(STD_INPUT_HANDLE));
  GetConsoleScreenBufferInfo(f_outHandle, f_consoleInfo);
  //
{$IFNDEF NO_ANSI_SUPPORT }
  if (g_wideApiSupported) then
{$ENDIF NO_ANSI_SUPPORT }
    SetConsoleTitleW(pwChar(caption))
{$IFNDEF NO_ANSI_SUPPORT }
  else
    SetConsoleTitleA(paChar(aString(caption)));
{$ENDIF NO_ANSI_SUPPORT }
  ;
  //
  if (0 <> icon) then
    SendMessage(0, WM_SETICON, ICON_BIG, icon);
  //
  if (0 <> textAttribute) then
    SetConsoleTextAttribute(f_outHandle, textAttribute);
end;

// --  --
destructor unaConsoleApp.Destroy();
begin
  inherited;
  //
  logMessage(#13#10'Terminated, have a nice OS.', c_logModeFlags_normal);
  //
  SetConsoleTextAttribute(f_outHandle, f_consoleInfo.wAttributes);
end;

// --  --
function unaConsoleApp.doInit(): bool;
begin
  result := true;
end;

// --  --
function unaConsoleApp.execute(globalIndex: unsigned): int;
begin
  while (not shouldStop) do begin
    //
    try
      //
      Sleep(100);
      processMessages();
    except
      // ignore exceptions
    end;
  end;
  //
  f_executeComplete := true;
  result := 0;
end;

// --  --
function unaConsoleApp.getConsoleInfo(): pConsoleScreenBufferInfo;
begin
  result := @f_consoleInfo;
end;

// --  --
procedure unaConsoleApp.run(enterStop: bool);
var
  s: aString;
begin
  if (f_ok) then begin
    //
    f_executeComplete := false;
    //
    start();
    //
    if (enterStop) then begin
      //
      logMessage(#13#10' -- Press ENTER to terminate the application --'#13#10, c_logModeFlags_normal);
      readLn(s);
    end
    else begin
      //
      while (not f_executeComplete) do begin
	//
	processMessages();
	Sleep(100);
      end;
    end;

    stop();
  end;
end;


// -- utility functions --

// --  --
function lockNonEmptyList(list: unaList; timeout: unsigned): bool;
begin
  if (lockList(list, timeout)) then begin
    //
    result := (0 < list.count);
    //
    if (not result) then
      unlockList(list);	// make sure list is not locked if false is returned
  end
  else
    result := false;
end;

// --  --
function lockList(list: unaList; timeout: unsigned = INFINITE): bool;
begin
  result := ((nil <> list) and list.lock(timeout));
end;

// --  --
procedure unlockList(list: unaList);
begin
  list.unlock();
end;

// --  --
function sameFiles(const fileName1, fileName2: wString): bool;
var
  f1, f2: unaMappedFile;
  offs: int64;
  subOfs: int;
  buf1, buf2: pArray;
  sz: unsigned;
begin
  result := false;
  //
  if (fileExists(fileName1) and fileExists(fileName2)) then begin
    //
    if (fileName1 <> fileName2) then begin
      //
      if (fileSize(fileName1) = fileSize(fileName2)) then begin
	//
	if (31 < fileSize(fileName1)) then begin
	  //
	  f1 := unaMappedFile.create(fileName1, PAGE_READONLY);
	  f2 := unaMappedFile.create(fileName2, PAGE_READONLY);
	  try
	    if (f1.size64 = f2.size64) then begin
	      //
	      if (0 < f1.size64) then begin
		//
		offs := 0;
		result := true;
		while (result and (offs < f1.size64)) do begin
		  //
		  sz := int(min(64 * $100000, f1.size64 - offs));  // assuming there is at least 64 MB in address space
		  buf1 := f1.mapView(offs, sz, subOfs);	// subOfs will be 0
		  buf2 := f2.mapView(offs, sz, subOfs);	// subOfs will be 0
		  //
		  if ((nil <> buf1) and (nil <> buf2)) then begin
		    //
		    result := mcompare(buf1, buf2, sz);
		    //
		    f1.unmapView(buf1);
		    f2.unmapView(buf2);
		  end
		  else begin
		    //
		    result := false;	// some problem in file mapping
		    break;
		  end;
		  //
		  inc(offs, f1.allocGran);
		end;
	      end
	      else
		result := true;	// both files are empty and thus are same
	      //
	    end
	    else
	      ;	// sizes are different
	  finally
	    //
	    freeAndNil(f1);
	    freeAndNil(f2);
	  end;
	end
	else begin
	  //
	  // compare small files using buffers
	  sz := int(fileSize(fileName1)); // will be less than 32
	  if (0 < sz) then begin
	    //
	    buf1 := malloc(sz);
	    buf2 := malloc(sz);
	    try
	      readFromFile(fileName1, buf1, sz);
	      readFromFile(fileName2, buf2, sz);
	      //
	      result := mcompare(buf1, buf2, sz);
	    finally
	      //
	      mrealloc(buf1);
	      mrealloc(buf2);
	    end;
	    //
	  end
	  else
	    result := true;	// both files are empty and thus are same
	  //
	end;
      end
      else
	;	// sizes are different
    end
    else
      result := true;	// same names
  end
  else
    ;	// one or both files are non-existing
end;


// --  --
function getFolderSize(const folder: wString; includeSubFolders: bool = true): int64;
var
  fl: unaFileList;
  i: int;
begin
  result := 0;
  //
  fl := unaFileList.create(folder, '*.*', includeSubFolders);
  try
    if (0 < fl.count) then begin
      //
      for i := 0 to fl.count - 1 do
	result := result + fl.getFileSize(i);
    end;
  finally
    freeAndNil(fl);
  end;
end;


// -- unit --

{$IFDEF DEBUG }
var
  pos: pointer;
  {$IFDEF LOG_UNACLASSES_INFOS }
  i: int;
  {$ENDIF LOG_UNACLASSES_INFOS }

{$ENDIF DEBUG }


initialization

{$IFDEF LOG_UNACLASSES_INFOS }
  logMessage('unaClasses - initializing..');
{$ENDIF LOG_UNACLASSES_INFOS }

{$IFDEF UNA_PROFILE }
  profId_unaClasses_unaList_doAdd := profileMarkRegister('unaClasses.unaList_doAdd()');
  profId_unaClasses_unaList_doInsert := profileMarkRegister('unaClasses.unaList_doInsert()');
  profId_unaClasses_unaList_doInsert_move := profileMarkRegister('unaClasses.unaList_doInsert()[move]');
  profId_unaClasses_unaList_doSetItem := profileMarkRegister('unaClasses.unaList_doSetItem()');
  profId_unaClasses_unaList_locate := profileMarkRegister('unaClasses.unaList_locate()');
  profId_unaClasses_unaList_doSetCapacity := profileMarkRegister('unaClasses.unaList_doSetCapacity()');
  profId_unaClasses_unaList_compare := profileMarkRegister('unaClasses.unaList_compare()');
  //
  {$IFDEF LOG_UNACLASSES_INFOS }
  logMessage('unaUtils - profiling is enabled.');
  {$ENDIF LOG_UNACLASSES_INFOS }
{$ENDIF UNA_PROFILE }

  // tell Delphi we love threads
  System.isMultiThread := true;

  // avoid creating instances of unaThread class before this
  // initialization section to complete
  //
  g_threadsGate := unaInProcessGate.create();

  // mark all thread spots as free
  fillChar(g_freeThreads, sizeOf(g_freeThreads), c_threadSpotIsFree);


finalization

{$IFDEF DEBUG }

  {$IFDEF LOG_UNACLASSES_INFOS }
  logMessage('unaClasses - finalizing..');
  {$ENDIF LOG_UNACLASSES_INFOS }
  //
  // ensure no threads were left abandoned
  //
  // try to locate free spot
  pos := mscanb(@g_freeThreads, sizeOf(g_freeThreads), c_threadSpotIsBusy);
  //
  {$IFDEF LOG_UNACLASSES_INFOS }
  if (nil <> pos) then begin
    //
    i := low(g_freeThreads);
    while (i <= high(g_freeThreads)) do begin
      //
      if (c_threadSpotIsBusy = g_freeThreads[i]) then
	logMessage('unaClasses - this thread was not released: ' + int2str(g_threads[i].r_threadId, 16));
      //
      inc(i);
    end;
  end;
  {$ENDIF LOG_UNACLASSES_INFOS }

{$ENDIF DEBUG }
  //
  freeAndNil(g_threadsGate);
end.
