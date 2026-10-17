library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.first_round_pkg.all;  -- wk_rk_array: (0..3) of std_logic_vector(15 downto 0)

entity last_round is 
  port(
    clk        : in  std_logic;
    reset      : in  std_logic;

    -- current 64-bit state entering last round
    X_in       : in  std_logic_vector(63 downto 0);

    -- (0)=WK2, (1)=WK3, (2)=RK_r, (3)=RK_r+1
    final_keys : in  wk_rk_array;

    -- from FSM
    encrypt_en : in  std_logic;
    r_cnt      : in  unsigned(4 downto 0);
    key_mode   : in  std_logic;
   
    en_last    : out std_logic;
    Y          : out std_logic_vector(63 downto 0)
  );
end entity last_round;

architecture rtl of last_round is

  component function_f_new is
    port (
      data_in  : in  std_logic_vector(15 downto 0);
      data_out : out std_logic_vector(15 downto 0)
    );
  end component;

  -- split state
  signal x0, x1, x2, x3 : std_logic_vector(15 downto 0);

  -- keys
  signal wk2, wk3, rk_r, rk_r1 : std_logic_vector(15 downto 0);

  -- F outputs
  signal f_x0, f_x2 : std_logic_vector(15 downto 0);

  -- mixed words
  signal x1_m, x3_m : std_logic_vector(15 downto 0);

  -- combinational + registered output
  signal y_comb, y_reg : std_logic_vector(63 downto 0);

  -- last-round detect
  signal rounds_max : unsigned(4 downto 0);
  signal en_last_d  : std_logic;

begin

  -- last round index depends on key mode
  rounds_max <= to_unsigned(24,5) when key_mode='0' else to_unsigned(30,5);

  -- enable only on the last round cycle
  en_last_d <= '1' when (encrypt_en='1' and r_cnt = rounds_max) else '0';
  

  -- split X_in: X0|X1|X2|X3
  x0 <= X_in(63 downto 48);
  x1 <= X_in(47 downto 32);
  x2 <= X_in(31 downto 16);
  x3 <= X_in(15 downto 0);

  -- unpack keys: WK2,WK3,RK_r,RK_r+1
  wk2   <= final_keys(0);
  wk3   <= final_keys(1);
  rk_r  <= final_keys(2);
  rk_r1 <= final_keys(3);

  -- F(X0), F(X2)
  U_F0 : function_f_new port map(data_in => x0, data_out => f_x0);
  U_F2 : function_f_new port map(data_in => x2, data_out => f_x2);

  -- mix into X1, X3
  x1_m <= std_logic_vector(unsigned(x1) xor unsigned(f_x0) xor unsigned(rk_r));
  x3_m <= std_logic_vector(unsigned(x3) xor unsigned(f_x2) xor unsigned(rk_r1));

  -- post-whitening on X0 and X2 (WK2/WK3)
  y_comb <= std_logic_vector(unsigned(x0) xor unsigned(wk2)) &
            x1_m &
            std_logic_vector(unsigned(x2) xor unsigned(wk3)) &
            x3_m;

  -- register only on last round
process(clk)
begin
  if rising_edge(clk) then
    if reset = '1' then
      y_reg   <= (others => '0');
      en_last <= '0';
    else
      en_last <= en_last_d;   -- always driven

      if en_last_d = '1' then
        y_reg <= y_comb;
      end if;

    end if;
  end if;
end process;
  Y<= y_reg;

end architecture rtl;


