library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_scheduler_80 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;

    key80    : in  std_logic_vector(79 downto 0);
    load_key : in  std_logic;  -- one-shot: load key80 into k0..k4 regs

    i_mod5   : in  std_logic_vector(2 downto 0);

    con_even : in  std_logic_vector(15 downto 0);
    con_odd  : in  std_logic_vector(15 downto 0);

    -- Whitening keys
    wk0      : out std_logic_vector(15 downto 0);
    wk1      : out std_logic_vector(15 downto 0);
    wk2      : out std_logic_vector(15 downto 0);
    wk3      : out std_logic_vector(15 downto 0);

    -- Round keys (COMBINATIONAL)
    rk_even  : out std_logic_vector(15 downto 0);
    rk_odd   : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of key_scheduler_80 is
  -- Registered subkeys
  signal k0, k1, k2, k3, k4 : std_logic_vector(15 downto 0) := (others => '0');

  -- Selected subkeys
  signal sel_a, sel_b : std_logic_vector(15 downto 0);

begin

  ------------------------------------------------------------------------------
  -- Load key into subkey registers (timed)
  ------------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        k0 <= (others => '0');
        k1 <= (others => '0');
        k2 <= (others => '0');
        k3 <= (others => '0');
        k4 <= (others => '0');
      else
        if load_key = '1' then
          -- key80 = k0||k1||k2||k3||k4 (MSB-first)
          k0 <= key80(79 downto 64);
          k1 <= key80(63 downto 48);
          k2 <= key80(47 downto 32);
          k3 <= key80(31 downto 16);
          k4 <= key80(15 downto 0);
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Whitening keys from REGISTERED subkeys (same byte-mix style as 128-bit)
  ------------------------------------------------------------------------------
  wk0 <= k0(15 downto 8) & k1(7 downto 0);
  wk1 <= k1(15 downto 8) & k0(7 downto 0);
  wk2 <= k4(15 downto 8) & k3(7 downto 0);
  wk3 <= k3(15 downto 8) & k4(7 downto 0);

  ------------------------------------------------------------------------------
  -- Select subkeys for this round (combinational)
  ------------------------------------------------------------------------------
  process(i_mod5, k0, k1, k2, k3, k4)
  begin
    case i_mod5 is
      when "000" | "010" =>   -- 0 or 2
        sel_a <= k2;
        sel_b <= k3;
      when "001" | "100" =>   -- 1 or 4
        sel_a <= k0;
        sel_b <= k1;
      when others =>          -- 3
        sel_a <= k4;
        sel_b <= k4;
    end case;
  end process;

  ------------------------------------------------------------------------------
  -- Round keys (combinational outputs)
  ------------------------------------------------------------------------------
  rk_even <= con_even xor sel_a;
  rk_odd  <= con_odd  xor sel_b;

end architecture;



