--------------------------------------------------------------------------------
-- Top Level Entity for CuteCar Robot Control System
-- Features: Nios II CPU, SDRAM, PWM Motor Control
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Top_CUTECAR is
  port (
    -- System Clock & Reset
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(0 downto 0);
    
    -- User I/O
    SW       : in  std_logic_vector(7 downto 0);
    LED      : out std_logic_vector(7 downto 0);
    
    -- SDRAM Physical Interface
    DRAM_CLK   : out   std_logic;
    DRAM_CKE   : out   std_logic;
    DRAM_ADDR  : out   std_logic_vector(12 downto 0);
    DRAM_BA    : out   std_logic_vector(1 downto 0);
    DRAM_CS_N  : out   std_logic;
    DRAM_CAS_N : out   std_logic;
    DRAM_RAS_N : out   std_logic;
    DRAM_WE_N  : out   std_logic;
    DRAM_DQ    : inout std_logic_vector(15 downto 0);
    DRAM_DQM   : out   std_logic_vector(1 downto 0);
    
    -- DC Motor Driver Interface
    MTRR_P : out std_logic;  -- Right motor forward
    MTRR_N : out std_logic;  -- Right motor backward
    MTRL_P : out std_logic;  -- Left motor forward
    MTRL_N : out std_logic   -- Left motor backward
  );
end entity Top_CUTECAR;

architecture rtl of Top_CUTECAR is
  
  --------------------------------------------------------------------------------
  -- Internal Signal Declarations
  --------------------------------------------------------------------------------
  
  -- PWM signals from Qsys to motor drivers
  signal motor_pwm_signals : std_logic_vector(3 downto 0);
  
  -- Intermediate motor control signals
  signal motor_right_fwd : std_logic;
  signal motor_right_bwd : std_logic;
  signal motor_left_fwd  : std_logic;
  signal motor_left_bwd  : std_logic;
  
  --------------------------------------------------------------------------------
  -- Component Declaration: Nios II System
  --------------------------------------------------------------------------------
  
  component Nios_CUTECAR is
    port (
      -- Clock interface
      clk_clk              : in    std_logic;
      
      -- Reset interface
      reset_reset_n        : in    std_logic;
      
      -- Parallel I/O: Switches
      switches_export      : in    std_logic_vector(7 downto 0);
      
      -- Parallel I/O: LEDs
      leds_export          : out   std_logic_vector(7 downto 0);
      
      -- SDRAM Controller Interface
      sdram_wire_addr      : out   std_logic_vector(12 downto 0);
      sdram_wire_ba        : out   std_logic_vector(1 downto 0);
      sdram_wire_cas_n     : out   std_logic;
      sdram_wire_cke       : out   std_logic;
      sdram_wire_cs_n      : out   std_logic;
      sdram_wire_dq        : inout std_logic_vector(15 downto 0);
      sdram_wire_dqm       : out   std_logic_vector(1 downto 0);
      sdram_wire_ras_n     : out   std_logic;
      sdram_wire_we_n      : out   std_logic;
      
      -- SDRAM Clock Output
      clocks_sdram_clk_clk : out   std_logic;
      
      -- PWM Conduit Export
      pwm_generation_avalon_interface_0_conduit_end_export : out std_logic_vector(3 downto 0)
    );
  end component Nios_CUTECAR;

begin

  --------------------------------------------------------------------------------
  -- Nios II System Instantiation
  --------------------------------------------------------------------------------
  
  nios_system_inst : Nios_CUTECAR
    port map (
      -- System clock and reset
      clk_clk                                              => CLOCK_50,
      reset_reset_n                                        => KEY(0),
      
      -- User interface
      switches_export                                      => SW,
      leds_export                                          => LED,
      
      -- SDRAM data and control
      sdram_wire_dq                                        => DRAM_DQ,
      sdram_wire_addr                                      => DRAM_ADDR,
      sdram_wire_ba                                        => DRAM_BA,
      sdram_wire_dqm                                       => DRAM_DQM,
      sdram_wire_cas_n                                     => DRAM_CAS_N,
      sdram_wire_ras_n                                     => DRAM_RAS_N,
      sdram_wire_we_n                                      => DRAM_WE_N,
      sdram_wire_cs_n                                      => DRAM_CS_N,
      sdram_wire_cke                                       => DRAM_CKE,
      
      -- SDRAM clock generation
      clocks_sdram_clk_clk                                 => DRAM_CLK,
      
      -- Motor PWM outputs
      pwm_generation_avalon_interface_0_conduit_end_export => motor_pwm_signals
    );
  
  --------------------------------------------------------------------------------
  -- PWM Signal Distribution to Motor Drivers
  -- Convention: bit[3:2] = right motor, bit[1:0] = left motor
  --             even bit = backward (N), odd bit = forward (P)
  --------------------------------------------------------------------------------
  
  -- Extract individual motor control signals
  motor_right_fwd <= motor_pwm_signals(3);
  motor_right_bwd <= motor_pwm_signals(2);
  motor_left_fwd  <= motor_pwm_signals(1);
  motor_left_bwd  <= motor_pwm_signals(0);
  
  -- Drive physical motor outputs
  MTRR_P <= motor_right_fwd;
  MTRR_N <= motor_right_bwd;
  MTRL_P <= motor_left_fwd;
  MTRL_N <= motor_left_bwd;

end architecture rtl;