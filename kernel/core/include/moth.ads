
with types;
with OpenConf;

package Moth with
   Spark_Mode     => On
is
   ---------------------------
   -- os_task_id definition --
   ---------------------------

   OS_TASK_ID_NONE      : constant := -1;
   OS_TASK_ID_ALL       : constant := -2;

   OS_MAX_TASK_CNT      : constant := OpenConf.CONFIG_MAX_TASK_COUNT;
   OS_TASK_ID_MAX       : constant := OS_MAX_TASK_CNT - 1;
   OS_TASK_ID_MIN       : constant := 0;

   subtype os_task_dest_id_t is types.int8_t
                           range OS_TASK_ID_ALL .. OS_TASK_ID_MAX;

   subtype os_task_id_t is os_task_dest_id_t
                           range OS_TASK_ID_NONE .. OS_TASK_ID_MAX;

   subtype os_task_id_param_t is os_task_id_t
                           range OS_TASK_ID_MIN .. OS_TASK_ID_MAX;

   ----------------------------
   -- os_status_t definition --
   ----------------------------

   OS_SUCCESS          : constant := 0;
   OS_ERROR_FIFO_FULL  : constant := -1;
   OS_ERROR_FIFO_EMPTY : constant := -2;
   OS_ERROR_DENIED     : constant := -3;
   OS_ERROR_RECEIVE    : constant := -4;
   OS_ERROR_PARAM      : constant := -5;
   OS_ERROR_MAX        : constant := OS_ERROR_PARAM;

   subtype os_status_t is types.int32_t
                           range OS_ERROR_MAX .. OS_SUCCESS;

   ------------------------------
   -- os_mbx_mask_t definition --
   ------------------------------

   OS_MBX_MASK_ALL      : constant := 16#ffffffff#;

   subtype os_mbx_mask_t is types.uint32_t;

   ---------------------
   -- Ghost functions --
   ---------------------

   function os_ghost_mbx_are_well_formed return Boolean
   with
      Ghost => true;

   function os_ghost_task_list_is_well_formed return Boolean
   with
      Ghost => true;

   function os_ghost_current_task_is_ready return Boolean
   with
      Ghost => true;

   -------------
   -- init --
   -------------

   procedure init (task_id : out os_task_id_param_t)
   with
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_mbx_are_well_formed and
	      os_ghost_current_task_is_ready;
   pragma Export (C, init, "os_init");

end Moth;
