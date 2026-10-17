library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity piccolo_top_tb is
end piccolo_top_tb;

architecture tb of piccolo_top_tb is

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal start        : std_logic := '0';
  signal key_mode     : std_logic := '0';

  signal key_in16     : std_logic_vector(15 downto 0) := (others => '0');
  signal data_in16    : std_logic_vector(15 downto 0) := (others => '0');

  signal cipher_out16 : std_logic_vector(15 downto 0);
  signal done         : std_logic;

  constant Tclk : time := 10 ns;

begin

  ---------------------------------------------------------------------------
  -- Clock
  ---------------------------------------------------------------------------
  clk <= not clk after Tclk/2;

  ---------------------------------------------------------------------------
  -- DUT
  ---------------------------------------------------------------------------
  DUT: entity work.piccolo_top
    port map(
      clk          => clk,
      rst          => rst,
      start        => start,
      key_mode     => key_mode,
      key_in16     => key_in16,
      data_in16    => data_in16,
      cipher_out16 => cipher_out16,
      done         => done
    );

  ---------------------------------------------------------------------------
  -- Stimulus
  ---------------------------------------------------------------------------
  stim: process
  begin

    -------------------------------------------------------------------------
    -- RESET
    -------------------------------------------------------------------------
    rst <= '1';
    wait for Tclk;
    rst <= '0';
    wait for Tclk;

    -------------------------------------------------------------------------
    -- ================= 80-bit =================
    -------------------------------------------------------------------------
    key_mode <= '0';

    start <= '1';
    wait for 1.5*Tclk;
    start <= '0';

    key_in16 <= x"0011"; data_in16 <= x"0123"; wait for Tclk;
    key_in16 <= x"2233"; data_in16 <= x"4567"; wait for Tclk;
    key_in16 <= x"4455"; data_in16 <= x"89AB"; wait for Tclk;
    key_in16 <= x"6677"; data_in16 <= x"CDEF"; wait for Tclk;
    key_in16 <= x"8899"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"0000"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"0000"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"0000"; data_in16 <= x"0000"; wait for Tclk;

    wait until done='1';
    wait for 5*Tclk;

    -------------------------------------------------------------------------
    -- ================= 128-bit =================
    -------------------------------------------------------------------------
    key_mode <= '1';

    start <= '1';
    wait for Tclk;
    start <= '0';

    key_in16 <= x"0011"; data_in16 <= x"0123"; wait for Tclk;
    key_in16 <= x"2233"; data_in16 <= x"4567"; wait for Tclk;
    key_in16 <= x"4455"; data_in16 <= x"89AB"; wait for Tclk;
    key_in16 <= x"6677"; data_in16 <= x"CDEF"; wait for Tclk;
    key_in16 <= x"8899"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"AABB"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"CCDD"; data_in16 <= x"0000"; wait for Tclk;
    key_in16 <= x"EEFF"; data_in16 <= x"0000"; wait for Tclk;

    wait until done='1';
    wait for 5*Tclk;

    -------------------------------------------------------------------------
    -- STOP SIMULATION
    -------------------------------------------------------------------------
    assert false report "Testbench finished successfully" severity failure;

  end process;

end tb;    
